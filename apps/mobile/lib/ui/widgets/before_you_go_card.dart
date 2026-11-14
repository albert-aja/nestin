import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/l10n/app_localizations.dart';
import '../../providers/before_you_go_provider.dart';
import 'before_you_go_sheet.dart';

class BeforeYouGoCard extends StatelessWidget {
  const BeforeYouGoCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Consumer<BeforeYouGoProvider>(
      builder: (context, provider, _) {
        final preset = provider.activePreset;
        final nextDeparture = provider.getNextScheduledDeparture();
        final activeSnooze = provider.activeSnoozeForNext();

        return InkWell(
          onTap: () => BeforeYouGoSheet.show(context),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardSurface(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: preset.color.withValues(alpha: 0.38),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: kScoutBlue.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Image.asset(
                        'assets/mascots/sprites/scout/before_you_go.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.door_front_door_outlined,
                          color: kScoutBlue,
                          size: 20,
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
                              const Flexible(
                                child: Text(
                                  'BeforeYouGo • Scout',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
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
                                  color: preset.allChecked
                                      ? AppColors.success.withValues(alpha: 0.18)
                                      : preset.color.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  l10n.pick(
                                    '${preset.checkedCount}/${preset.totalCount} Ready',
                                    '${preset.checkedCount}/${preset.totalCount} Siap',
                                  ),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: preset.allChecked
                                        ? AppColors.success
                                        : preset.color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            nextDeparture != null
                                ? l10n.pick(
                                    '🧭 Next: ${nextDeparture.title} • ${nextDeparture.recurrenceSummary} ${nextDeparture.formattedDepartureTime} (${nextDeparture.leadLabel})',
                                    '🧭 Berikutnya: ${nextDeparture.title} • ${nextDeparture.recurrenceSummary} ${nextDeparture.formattedDepartureTime} (${nextDeparture.leadLabel})',
                                  )
                                : l10n.pick(
                                    '🧭 ${provider.events.length} departure schedules • Tap to add heads-up',
                                    '🧭 ${provider.events.length} jadwal berangkat • Ketuk untuk tambah pengingat',
                                  ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (activeSnooze != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              l10n.pick(
                                '⏰ Snoozed +5m until ${activeSnooze.formattedSnoozedUntil}${activeSnooze.snoozeCount > 1 ? ' (${activeSnooze.snoozeCount}x)' : ''}',
                                '⏰ Ditunda +5m hingga ${activeSnooze.formattedSnoozedUntil}${activeSnooze.snoozeCount > 1 ? ' (${activeSnooze.snoozeCount}x)' : ''}',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: kScoutAmber,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Reset Checklist',
                      onPressed: () => provider.resetPresetItems(preset.id),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      tooltip: 'Schedule Departure Heads-Up',
                      onPressed: () => showDepartureEventEditorDialog(
                        context,
                        initialPresetId: preset.id,
                      ),
                      icon: const Icon(
                        Icons.add_circle_outline_rounded,
                        color: kScoutBlue,
                        size: 20,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Quick Preset Switcher Strip
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: provider.presets.map((p) {
                      final selected = p.id == preset.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          selected: selected,
                          visualDensity: VisualDensity.compact,
                          selectedColor: p.color.withValues(alpha: 0.22),
                          avatar: Icon(
                            p.icon,
                            size: 13,
                            color: selected
                                ? p.color
                                : AppColors.textSecondary(context),
                          ),
                          label: Text(
                            p.name,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? p.color
                                  : AppColors.textPrimary(context),
                            ),
                          ),
                          onSelected: (_) => provider.selectActivePreset(p.id),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                if (preset.items.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Divider(height: 1, color: AppColors.border(context)),
                  const SizedBox(height: 6),
                  ...preset.items.take(5).map(
                        (item) => InkWell(
                          onTap: () => provider.toggleItem(preset.id, item.id),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Icon(
                                  item.isChecked
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  size: 18,
                                  color: item.isChecked
                                      ? AppColors.success
                                      : AppColors.textSecondary(context),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    item.label,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      decoration: item.isChecked
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: item.isChecked
                                          ? AppColors.textSecondary(context)
                                          : AppColors.textPrimary(context),
                                    ),
                                  ),
                                ),
                                if (item.isEssential)
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 13,
                                    color: kScoutAmber,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  if (preset.items.length > 5) ...[
                    const SizedBox(height: 4),
                    Text(
                      l10n.pick(
                        '+${preset.items.length - 5} more items • Tap card to reorder or edit',
                        '+${preset.items.length - 5} item lagi • Ketuk kartu untuk ubah',
                      ),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (preset.items.isNotEmpty && !preset.allChecked)
                        TextButton.icon(
                          onPressed: () => provider.markPresetAllReady(preset.id),
                          icon: const Icon(
                            Icons.done_all_rounded,
                            size: 15,
                            color: AppColors.success,
                          ),
                          label: Text(
                            l10n.pick('Mark All Ready', 'Siap Semua'),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                          ),
                        )
                      else if (preset.allChecked)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.verified_rounded,
                              size: 14,
                              color: AppColors.success,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l10n.pick('All Ready ✓', 'Semua Siap ✓'),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        )
                      else
                        const SizedBox.shrink(),
                      TextButton.icon(
                        onPressed: () => BeforeYouGoSheet.show(
                          context,
                          initialTab: 1,
                        ),
                        icon: const Icon(Icons.notifications_active_outlined,
                            size: 14, color: kScoutBlue),
                        label: Text(
                          provider.events.isEmpty
                              ? l10n.pick(
                                  'Set Departure Alerts ->',
                                  'Atur Pengingat Berangkat ->',
                                )
                              : l10n.pick(
                                  'Manage ${provider.events.length} Schedules ->',
                                  'Kelola ${provider.events.length} Jadwal ->',
                                ),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: kScoutBlue,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
