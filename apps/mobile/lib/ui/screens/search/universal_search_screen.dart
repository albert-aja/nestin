import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../providers/note_provider.dart';
import '../../../providers/task_provider.dart';
import '../../../providers/calendar_provider.dart';
import '../../../providers/journal_provider.dart';
import '../../../providers/collection_provider.dart';
import '../../../providers/alarm_provider.dart';
import '../../../providers/reading_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/geofence_provider.dart';
import '../../../providers/before_you_go_provider.dart';
import '../../../providers/money_provider.dart';
import '../../../providers/device_control_provider.dart';
import '../../../providers/automation_provider.dart';
import '../../../data/models/money_transaction.dart';

class UniversalSearchScreen extends StatefulWidget {
  const UniversalSearchScreen({super.key});

  @override
  State<UniversalSearchScreen> createState() => _UniversalSearchScreenState();
}

class _UniversalSearchScreenState extends State<UniversalSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final noteProvider = Provider.of<NoteProvider>(context);
    final taskProvider = Provider.of<TaskProvider>(context);
    final calendarProvider = Provider.of<CalendarProvider>(context);
    final journalProvider = Provider.of<JournalProvider>(context);
    final collectionProvider = Provider.of<CollectionProvider>(context);
    final alarmProvider = Provider.of<AlarmProvider>(context);
    final readingProvider = Provider.of<ReadingProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    GeofenceProvider? geofenceProvider;
    try {
      geofenceProvider = Provider.of<GeofenceProvider>(context);
    } catch (_) {}
    MoneyProvider? moneyProvider;
    try {
      moneyProvider = Provider.of<MoneyProvider>(context);
    } catch (_) {}
    BeforeYouGoProvider? beforeYouGoProvider;
    try {
      beforeYouGoProvider = Provider.of<BeforeYouGoProvider>(context);
    } catch (_) {}
    DeviceControlProvider? deviceControlProvider;
    try {
      deviceControlProvider = Provider.of<DeviceControlProvider>(context);
    } catch (_) {}
    AutomationProvider? automationProvider;
    try {
      automationProvider = Provider.of<AutomationProvider>(context);
    } catch (_) {}

    final q = _query.toLowerCase().trim();

    final matchingNotes = q.isEmpty
        ? []
        : noteProvider.notes
            .where((n) => n.title.toLowerCase().contains(q) || n.content.toLowerCase().contains(q))
            .toList();

    final matchingTasks = q.isEmpty
        ? []
        : taskProvider.tasks
            .where((t) => t.title.toLowerCase().contains(q) || t.notes.toLowerCase().contains(q))
            .toList();

    final matchingEvents = q.isEmpty
        ? []
        : calendarProvider.events
            .where((e) => e.title.toLowerCase().contains(q) || e.description.toLowerCase().contains(q))
            .toList();

    final matchingJournal = q.isEmpty
        ? []
        : journalProvider.journalEntries
            .where((j) =>
                !settings.isEntryLocked(j) &&
                (j.title.toLowerCase().contains(q) ||
                    j.content.toLowerCase().contains(q)))
            .toList();

    final matchingWishlist = q.isEmpty
        ? []
        : collectionProvider.wishlist
            .where((w) => w.title.toLowerCase().contains(q) || w.description.toLowerCase().contains(q))
            .toList();

    final matchingCollections = q.isEmpty
        ? []
        : collectionProvider.collections
            .where((c) =>
                c.title.toLowerCase().contains(q) ||
                c.description.toLowerCase().contains(q) ||
                c.entries.any((e) =>
                    e.text.toLowerCase().contains(q) ||
                    (e.category?.toLowerCase().contains(q) ?? false)))
            .toList();

    final matchingAlarms = q.isEmpty
        ? []
        : alarmProvider.alarms
            .where((a) => a.title.toLowerCase().contains(q) || a.description.toLowerCase().contains(q))
            .toList();

    final matchingReading = q.isEmpty
        ? []
        : readingProvider.items
            .where((b) =>
                b.title.toLowerCase().contains(q) ||
                b.author.toLowerCase().contains(q) ||
                b.category.toLowerCase().contains(q) ||
                (b.notes?.toLowerCase().contains(q) ?? false))
            .toList();

    final matchingLocationReminders = q.isEmpty || geofenceProvider == null
        ? []
        : geofenceProvider.reminders.where((r) {
            final place = geofenceProvider!.findPlaceById(r.placeId);
            final placeName = place?.name.toLowerCase() ?? '';
            final placeAddr = place?.address.toLowerCase() ?? '';
            return r.title.toLowerCase().contains(q) ||
                r.notes.toLowerCase().contains(q) ||
                placeName.contains(q) ||
                placeAddr.contains(q);
          }).toList();

    final matchingMoneyTxs = q.isEmpty || moneyProvider == null
        ? []
        : moneyProvider.transactions.where((t) {
            final cat =
                moneyProvider!.findCategoryById(t.categoryId)?.name.toLowerCase() ?? '';
            final acct =
                moneyProvider.findAccountById(t.accountId)?.name.toLowerCase() ?? '';
            return t.description.toLowerCase().contains(q) ||
                cat.contains(q) ||
                acct.contains(q);
          }).toList();

    final matchingMoneyAccounts = q.isEmpty || moneyProvider == null
        ? []
        : moneyProvider.accounts
            .where((a) =>
                a.name.toLowerCase().contains(q) ||
                a.type.label.toLowerCase().contains(q) ||
                a.description.toLowerCase().contains(q))
            .toList();

    final matchingDepartureEvents = q.isEmpty || beforeYouGoProvider == null
        ? []
        : beforeYouGoProvider.events.where((ev) {
            final preset = beforeYouGoProvider!.findPresetById(ev.presetId);
            return ev.title.toLowerCase().contains(q) ||
                ev.recurrenceSummary.toLowerCase().contains(q) ||
                (preset?.name.toLowerCase().contains(q) ?? false);
          }).toList();

    final matchingDeparturePresets = q.isEmpty || beforeYouGoProvider == null
        ? []
        : beforeYouGoProvider.presets.where((p) {
            return p.name.toLowerCase().contains(q) ||
                p.items.any((i) => i.label.toLowerCase().contains(q));
          }).toList();

    final matchingPhoneModes = q.isEmpty || deviceControlProvider == null
        ? []
        : deviceControlProvider.phoneModes
            .where((m) =>
                m.name.toLowerCase().contains(q) ||
                m.description.toLowerCase().contains(q))
            .toList();

    final matchingAutomations = q.isEmpty || automationProvider == null
        ? []
        : automationProvider.rules
            .where((r) =>
                r.name.toLowerCase().contains(q) ||
                r.description.toLowerCase().contains(q))
            .toList();

    final totalCount = matchingNotes.length +
        matchingTasks.length +
        matchingEvents.length +
        matchingJournal.length +
        matchingWishlist.length +
        matchingCollections.length +
        matchingAlarms.length +
        matchingReading.length +
        matchingLocationReminders.length +
        matchingMoneyTxs.length +
        matchingMoneyAccounts.length +
        matchingDepartureEvents.length +
        matchingDeparturePresets.length +
        matchingPhoneModes.length +
        matchingAutomations.length;

    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.pick(
              'Search notes, tasks, events, journal...',
              'Cari catatan, tugas, acara, jurnal...',
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          onChanged: (val) => setState(() => _query = val),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_rounded),
              onPressed: () {
                _searchController.clear();
                setState(() => _query = '');
              },
            ),
        ],
      ),
      body: q.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_rounded,
                      size: 56, color: AppColors.textSecondary(context)),
                  const SizedBox(height: 12),
                  Text(
                    l10n.pick('Universal Search', 'Pencarian Universal'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.pick(
                      'Search across notes, tasks, events, journal & alarms',
                      'Cari catatan, tugas, acara, jurnal & alarm',
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            )
          : totalCount == 0
              ? Center(
                  child: Text(
                    l10n.pick(
                      'No matching records found',
                      'Tidak ada data yang cocok ditemukan',
                    ),
                    style: TextStyle(color: AppColors.textSecondary(context)),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (matchingNotes.isNotEmpty) ...[
                      _buildHeader(l10n.pick('Notes', 'Catatan'), matchingNotes.length, AppColors.accent),
                      ...matchingNotes.map((n) => _buildResultTile(
                            title: n.title.isEmpty
                                ? l10n.pick('Untitled Note', 'Catatan Tanpa Judul')
                                : n.title,
                            subtitle: n.content,
                            icon: Icons.description_outlined,
                            color: AppColors.accent,
                          )),
                      const SizedBox(height: 16),
                    ],
                    if (matchingTasks.isNotEmpty) ...[
                      _buildHeader(l10n.pick('Tasks', 'Tugas'), matchingTasks.length, AppColors.catWork),
                      ...matchingTasks.map((t) => _buildResultTile(
                            title: t.title,
                            subtitle: t.isCompleted
                                ? l10n.tr('completed')
                                : l10n.pick('Pending', 'Tertunda'),
                            icon: Icons.check_circle_outline_rounded,
                            color: AppColors.catWork,
                          )),
                      const SizedBox(height: 16),
                    ],
                    if (matchingEvents.isNotEmpty) ...[
                      _buildHeader(l10n.pick('Calendar Events', 'Acara Kalender'), matchingEvents.length, AppColors.primaryLight),
                      ...matchingEvents.map((e) => _buildResultTile(
                            title: e.title,
                            subtitle: e.formattedTime(),
                            icon: Icons.event_rounded,
                            color: AppColors.primaryLight,
                          )),
                      const SizedBox(height: 16),
                    ],
                    if (matchingJournal.isNotEmpty) ...[
                      _buildHeader(l10n.pick('Journal Entries', 'Entri Jurnal'), matchingJournal.length, AppColors.catPersonal),
                      ...matchingJournal.map((j) => _buildResultTile(
                            title: j.title.isEmpty
                                ? l10n.pick('Journal Entry', 'Entri Jurnal')
                                : j.title,
                            subtitle: j.content,
                            icon: Icons.book_outlined,
                            color: AppColors.catPersonal,
                          )),
                      const SizedBox(height: 16),
                    ],
                    if (matchingCollections.isNotEmpty) ...[
                      _buildHeader(
                        l10n.pick('Lists & Packing', 'Daftar & Kemas'),
                        matchingCollections.length,
                        AppColors.primary,
                      ),
                      ...matchingCollections.map((c) => _buildResultTile(
                            title: c.title,
                            subtitle:
                                '${c.checkedCount}/${c.totalCount}${c.description.isNotEmpty ? ' • ${c.description}' : ''}',
                            icon: c.displayIcon,
                            color: Color(c.colorValue),
                          )),
                      const SizedBox(height: 16),
                    ],
                    if (matchingWishlist.isNotEmpty) ...[
                      _buildHeader(l10n.pick('Wishlist', 'Daftar Keinginan'), matchingWishlist.length, AppColors.catHealth),
                      ...matchingWishlist.map((w) => _buildResultTile(
                            title: w.title,
                            subtitle: w.formattedPrice(),
                            icon: Icons.card_giftcard_rounded,
                            color: AppColors.catHealth,
                          )),
                      const SizedBox(height: 16),
                    ],
                    if (matchingAlarms.isNotEmpty) ...[
                      _buildHeader(l10n.pick('Alarms', 'Alarm'), matchingAlarms.length, AppColors.primary),
                      ...matchingAlarms.map((a) => _buildResultTile(
                            title: a.title,
                            subtitle: a.formattedTime(),
                            icon: Icons.alarm_rounded,
                            color: AppColors.primary,
                          )),
                      const SizedBox(height: 16),
                    ],
                    if (matchingReading.isNotEmpty) ...[
                      _buildHeader(l10n.pick('Reading List', 'Daftar Bacaan'), matchingReading.length, const Color(0xFF10B981)),
                      ...matchingReading.map((b) => _buildResultTile(
                            title: b.title,
                            subtitle:
                                '${b.author.isNotEmpty ? "${b.author} • " : ""}${b.formattedProgress}',
                            icon: Icons.menu_book_rounded,
                            color: const Color(0xFF10B981),
                          )),
                      const SizedBox(height: 16),
                    ],
                    if (matchingLocationReminders.isNotEmpty &&
                        geofenceProvider != null) ...[
                      _buildHeader(
                        l10n.pick('Location Reminders', 'Pengingat Lokasi'),
                        matchingLocationReminders.length,
                        const Color(0xFF3B82F6),
                      ),
                      ...matchingLocationReminders.map((r) {
                        final placeName =
                            geofenceProvider!.findPlaceById(r.placeId)?.name ??
                                l10n.pick('Saved Place', 'Tempat Tersimpan');
                        return _buildResultTile(
                          title: r.title,
                          subtitle:
                              '${r.triggerType.emoji} ${r.triggerType.shortLabel} $placeName',
                          icon: Icons.location_on_rounded,
                          color: const Color(0xFF3B82F6),
                        );
                      }),
                      const SizedBox(height: 16),
                    ],
                    if (matchingMoneyAccounts.isNotEmpty &&
                        moneyProvider != null) ...[
                      _buildHeader(
                        l10n.pick('Money Wallets & Accounts', 'Dompet & Akun Keuangan'),
                        matchingMoneyAccounts.length,
                        const Color(0xFFF59E0B),
                      ),
                      ...matchingMoneyAccounts.map((a) => _buildResultTile(
                            title: a.name,
                            subtitle:
                                '${a.type.label} • ${moneyProvider!.formatAmount(a.currentBalanceMinor)}',
                            icon: Icons.account_balance_wallet_rounded,
                            color: const Color(0xFFF59E0B),
                          )),
                      const SizedBox(height: 16),
                    ],
                    if (matchingMoneyTxs.isNotEmpty &&
                        moneyProvider != null) ...[
                      _buildHeader(
                        l10n.pick('Money Transactions', 'Transaksi Keuangan'),
                        matchingMoneyTxs.length,
                        const Color(0xFFF59E0B),
                      ),
                      ...matchingMoneyTxs.map((t) {
                        final MoneyTransaction tx = t as MoneyTransaction;
                        final catName =
                            moneyProvider!.findCategoryById(tx.categoryId)?.name ??
                                tx.type.label;
                        return _buildResultTile(
                          title: tx.description.isNotEmpty ? tx.description : catName,
                          subtitle:
                              '${tx.type.label} • ${moneyProvider.formatAmount(tx.amountMinor)}',
                          icon: tx.type.icon,
                          color: tx.type.color,
                        );
                      }),
                      const SizedBox(height: 16),
                    ],
                    if (matchingDepartureEvents.isNotEmpty &&
                        beforeYouGoProvider != null) ...[
                      _buildHeader(
                        l10n.pick('BeforeYouGo Trips', 'Jadwal BeforeYouGo'),
                        matchingDepartureEvents.length,
                        const Color(0xFF3B82F6),
                      ),
                      ...matchingDepartureEvents.map((ev) {
                        final preset =
                            beforeYouGoProvider!.findPresetById(ev.presetId);
                        return _buildResultTile(
                          title: ev.title,
                          subtitle:
                              '${ev.recurrenceSummary} • ${ev.formattedDepartureTime} • ${ev.leadLabel}${preset != null ? " • ${preset.name}" : ""}',
                          icon: Icons.departure_board_rounded,
                          color: const Color(0xFF3B82F6),
                        );
                      }),
                      const SizedBox(height: 16),
                    ],
                    if (matchingDeparturePresets.isNotEmpty &&
                        beforeYouGoProvider != null) ...[
                      _buildHeader(
                        l10n.pick('BeforeYouGo Checklists', 'Daftar BeforeYouGo'),
                        matchingDeparturePresets.length,
                        const Color(0xFF3B82F6),
                      ),
                      ...matchingDeparturePresets.map((p) => _buildResultTile(
                            title: l10n.pick(
                              '${p.name} Checklist',
                              'Daftar ${p.name}',
                            ),
                            subtitle: l10n.pick(
                              '${p.checkedCount}/${p.totalCount} items packed',
                              '${p.checkedCount}/${p.totalCount} item siap',
                            ),
                            icon: p.icon,
                            color: p.color,
                          )),
                    ],
                    if (matchingPhoneModes.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildHeader(
                        l10n.pick('Phone Modes', 'Mode Ponsel'),
                        matchingPhoneModes.length,
                        AppColors.info,
                      ),
                      ...matchingPhoneModes.map((m) => _buildResultTile(
                            title: m.name,
                            subtitle: m.description,
                            icon: Icons.shield_moon_rounded,
                            color: Color(m.colorValue),
                          )),
                    ],
                    if (matchingAutomations.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildHeader(
                        l10n.pick('Automation Rules', 'Aturan Otomasi'),
                        matchingAutomations.length,
                        AppColors.accent,
                      ),
                      ...matchingAutomations.map((r) => _buildResultTile(
                            title: r.name,
                            subtitle: '${r.triggerType.label} • P${r.priority}',
                            icon: Icons.auto_awesome_rounded,
                            color: AppColors.accent,
                          )),
                    ],
                  ],
                ),
    );
  }

  Widget _buildHeader(String title, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 14,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 8),
          Text(
            '$title ($count)',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildResultTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary(context),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

