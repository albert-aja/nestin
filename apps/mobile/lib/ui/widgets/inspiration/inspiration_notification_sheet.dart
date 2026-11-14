import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/inspiration_models.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../providers/inspiration_provider.dart';

class InspirationNotificationSheet extends StatefulWidget {
  const InspirationNotificationSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.sheetSurface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const InspirationNotificationSheet(),
    );
  }

  @override
  State<InspirationNotificationSheet> createState() =>
      _InspirationNotificationSheetState();
}

class _InspirationNotificationSheetState
    extends State<InspirationNotificationSheet> {
  late InspirationNotificationPreferences _draft;

  @override
  void initState() {
    super.initState();
    _draft = context.read<InspirationProvider>().notificationPreferences;
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _draft.preferredHour,
        minute: _draft.preferredMinute,
      ),
    );
    if (picked == null) return;
    final hh = picked.hour.toString().padLeft(2, '0');
    final mm = picked.minute.toString().padLeft(2, '0');
    setState(() {
      _draft = _draft.copyWith(preferredTime: '$hh:$mm');
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = context.watch<InspirationProvider>();
    final locale = l10n.isIndonesian ? 'id' : 'en';

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            Text(
              l10n.pick(
                'Daily Inspiration Reminders',
                'Pengingat Inspirasi Harian',
              ),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.pick(
                'Optional & calm — turned off by default so Nestin never interrupts without permission.',
                'Opsional & tenang — nonaktif secara default agar tidak mengganggu tanpa izin.',
              ),
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(
                l10n.pick(
                  'Enable Daily Quote Reminder',
                  'Aktifkan Pengingat Kutipan Harian',
                ),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              value: _draft.dailyEnabled,
              onChanged: (val) => setState(() {
                _draft = _draft.copyWith(dailyEnabled: val);
              }),
            ),
            if (_draft.dailyEnabled) ...[
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_rounded, color: AppColors.accent),
                title: Text(l10n.pick('Preferred Time', 'Waktu Pilihan')),
                trailing: Text(
                  _draft.preferredTime,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent,
                    fontSize: 15,
                  ),
                ),
                onTap: _pickTime,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.pick('Frequency', 'Frekuensi'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: InspirationNotificationFrequency.values.map((freq) {
                  final selected = _draft.frequency == freq;
                  final label = switch (freq) {
                    InspirationNotificationFrequency.daily =>
                      l10n.pick('Daily', 'Setiap Hari'),
                    InspirationNotificationFrequency.weekdays =>
                      l10n.pick('Weekdays', 'Hari Kerja'),
                    InspirationNotificationFrequency.weekly =>
                      l10n.pick('Weekly', 'Mingguan'),
                  };
                  return ChoiceChip(
                    label: Text(label),
                    selected: selected,
                    onSelected: (_) => setState(() {
                      _draft = _draft.copyWith(frequency: freq);
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.pick('Language', 'Bahasa Kutipan'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('English'),
                    selected: _draft.preferredLocale == 'en',
                    onSelected: (_) => setState(() {
                      _draft = _draft.copyWith(preferredLocale: 'en');
                    }),
                  ),
                  ChoiceChip(
                    label: const Text('Bahasa Indonesia'),
                    selected: _draft.preferredLocale == 'id',
                    onSelected: (_) => setState(() {
                      _draft = _draft.copyWith(preferredLocale: 'id');
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                l10n.pick(
                  'Category Filter (optional)',
                  'Filter Kategori (opsional)',
                ),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: provider.categories.map((cat) {
                  final selected = _draft.preferredCategoryIds.contains(cat.id);
                  return FilterChip(
                    label: Text(cat.labelForLocale(locale)),
                    selected: selected,
                    onSelected: (on) {
                      final next = List<String>.from(_draft.preferredCategoryIds);
                      if (on) {
                        next.add(cat.id);
                      } else {
                        next.remove(cat.id);
                      }
                      setState(() {
                        _draft = _draft.copyWith(preferredCategoryIds: next);
                      });
                    },
                  );
                }).toList(),
              ),
            ],
            const Divider(height: 24),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(
                l10n.pick(
                  'Submission Review Alerts',
                  'Notifikasi Status Pengajuan',
                ),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: Text(
                l10n.pick(
                  'Notify when a moderator approves or reviews your submitted quote.',
                  'Beri tahu saat moderator meninjau kutipan Anda.',
                ),
                style: const TextStyle(fontSize: 11),
              ),
              value: _draft.submissionUpdatesEnabled,
              onChanged: (val) => setState(() {
                _draft = _draft.copyWith(submissionUpdatesEnabled: val);
              }),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await provider.sendPreviewNotification();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              l10n.pick(
                                'Preview notification dispatched',
                                'Pratinjau notifikasi dikirim',
                              ),
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.notifications_none_rounded, size: 18),
                    label: Text(l10n.pick('Preview', 'Pratinjau')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      await provider.updateNotificationPreferences(_draft);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _draft.dailyEnabled
                                  ? l10n.pick(
                                      'Daily inspiration set for ${_draft.preferredTime}',
                                      'Inspirasi harian diatur pukul ${_draft.preferredTime}',
                                    )
                                  : l10n.pick(
                                      'Daily inspiration notifications paused',
                                      'Notifikasi inspirasi harian dimatikan',
                                    ),
                            ),
                          ),
                        );
                      }
                    },
                    child: Text(l10n.pick('Save Preferences', 'Simpan Pengaturan')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
