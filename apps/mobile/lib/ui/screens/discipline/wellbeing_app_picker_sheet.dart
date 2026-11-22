import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/app_restriction.dart';
import '../../../providers/device_control_provider.dart';
import '../../widgets/skeleton_shimmer.dart';

/// Native-aware application discovery & selection sheet for Roo Digital Discipline.
///
/// Queries [DeviceControlProvider.discoverInstalledApps] on Android (via
/// LAUNCHER package queries), preserves preset entries cleanly, and reports
/// Apple FamilyControls limitations honestly on iOS without faking apps.
class WellbeingAppPickerSheet extends StatefulWidget {
  final Set<String> initialSelectedPackages;
  final Map<String, String> initialAppNames;
  final bool multiSelect;
  final String title;

  const WellbeingAppPickerSheet({
    super.key,
    this.initialSelectedPackages = const {},
    this.initialAppNames = const {},
    this.multiSelect = true,
    this.title = 'Select Applications',
  });

  static Future<Map<String, String>?> pickApps(
    BuildContext context, {
    Set<String> initialSelected = const {},
    Map<String, String> initialNames = const {},
    bool multiSelect = true,
    String title = 'Select Applications',
  }) {
    return showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WellbeingAppPickerSheet(
        initialSelectedPackages: initialSelected,
        initialAppNames: initialNames,
        multiSelect: multiSelect,
        title: title,
      ),
    );
  }

  @override
  State<WellbeingAppPickerSheet> createState() =>
      _WellbeingAppPickerSheetState();
}

class _WellbeingAppPickerSheetState extends State<WellbeingAppPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  late Map<String, String> _selected;
  String _selectedCategory = 'all';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _selected = {};
    for (final pkg in widget.initialSelectedPackages) {
      _selected[pkg] = widget.initialAppNames[pkg] ?? pkg;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _discover());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _discover() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      await Provider.of<DeviceControlProvider>(
        context,
        listen: false,
      ).discoverInstalledApps();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<InstalledAppInfo> _mergedApps(DeviceControlProvider provider) {
    final byPkg = <String, InstalledAppInfo>{};
    for (final app in provider.discoveredApps) {
      byPkg[app.packageName] = app;
    }
    for (final rule in provider.appRules) {
      byPkg.putIfAbsent(
        rule.packageName,
        () => InstalledAppInfo(
          packageName: rule.packageName,
          appName: rule.displayName,
          category: rule.category,
          iosBundleHint: rule.iosBundleHint,
        ),
      );
    }
    for (final entry in _selected.entries) {
      byPkg.putIfAbsent(
        entry.key,
        () => InstalledAppInfo(packageName: entry.key, appName: entry.value),
      );
    }

    final query = _searchCtrl.text.trim().toLowerCase();
    final list = byPkg.values.where((app) {
      if (_selectedCategory != 'all' && app.category != _selectedCategory) {
        return false;
      }
      if (query.isEmpty) return true;
      return app.appName.toLowerCase().contains(query) ||
          app.packageName.toLowerCase().contains(query);
    }).toList();

    list.sort((a, b) {
      final aSel = _selected.containsKey(a.packageName);
      final bSel = _selected.containsKey(b.packageName);
      if (aSel != bSel) return aSel ? -1 : 1;
      return a.appName.toLowerCase().compareTo(b.appName.toLowerCase());
    });
    return list;
  }

  Future<void> _showAddCustomPackageDialog() async {
    final nameCtrl = TextEditingController();
    final pkgCtrl = TextEditingController();
    final added = await showDialog<InstalledAppInfo>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Custom App / Package'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'App Name (e.g. Reddit)',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: pkgCtrl,
              decoration: const InputDecoration(
                labelText: 'Package / Bundle ID (e.g. com.reddit.frontpage)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final pkg = pkgCtrl.text.trim();
              final name = nameCtrl.text.trim();
              if (pkg.isEmpty) return;
              Navigator.pop(
                ctx,
                InstalledAppInfo(
                  packageName: pkg,
                  appName: name.isEmpty ? pkg : name,
                ),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (added != null && mounted) {
      setState(() {
        if (!widget.multiSelect) _selected.clear();
        _selected[added.packageName] = added.appName;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = context.watch<DeviceControlProvider>();
    final apps = _mergedApps(provider);
    final isIosWithoutEntitlement = provider.registry.platform == 'ios' &&
        !provider.registry.hasFamilyControlsEntitlement;

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.94,
      builder: (_, scrollCtrl) => Material(
        color: AppColors.sheetSurface(context),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          side: BorderSide(color: AppColors.border(context)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.scrimHandle(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          l10n.tr('selected', {'selected_length': _selected.length}),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.tr('add_custom_package'),
                    icon: const Icon(Icons.add_box_outlined),
                    onPressed: _showAddCustomPackageDialog,
                  ),
                  IconButton(
                    tooltip: l10n.tr('rescan_apps'),
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                    onPressed: _loading ? null : _discover,
                  ),
                ],
              ),
            ),
            if (isIosWithoutEntitlement)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  l10n.tr('ios_hides_third_party_installed_apps'),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: l10n.tr('search_installed_apps_or_package_id'),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final cat in [
                    ('all', 'All'),
                    ('social', 'Social'),
                    ('video', 'Video'),
                    ('gaming', 'Gaming'),
                    ('productivity', 'Productivity'),
                    ('other', 'Other'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(cat.$2),
                        selected: _selectedCategory == cat.$1,
                        onSelected: (_) =>
                            setState(() => _selectedCategory = cat.$1),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: _loading
                  ? const SkeletonCardList(
                      itemCount: 5,
                      leadingSize: 40,
                      leadingBorderRadius: 20,
                      lineCount: 2,
                      showTrailingPill: false,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    )
                  : apps.isEmpty
                  ? Center(
                      child: Text(
                        l10n.tr('no_matching_apps_found'),
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollCtrl,
                      itemCount: apps.length,
                      itemBuilder: (context, index) {
                        final app = apps[index];
                        final checked = _selected.containsKey(app.packageName);
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: checked
                                ? AppColors.accent.withValues(alpha: 0.2)
                                : AppColors.elevatedSurface(context),
                            child: Text(
                              app.appName.isNotEmpty
                                  ? app.appName.substring(0, 1).toUpperCase()
                                  : 'A',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: checked
                                    ? AppColors.accent
                                    : AppColors.textPrimary(context),
                              ),
                            ),
                          ),
                          title: Text(
                            app.appName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            '${app.packageName} · ${app.category}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                          trailing: Checkbox(
                            value: checked,
                            onChanged: (v) {
                              setState(() {
                                if (!widget.multiSelect) _selected.clear();
                                if (v == true) {
                                  _selected[app.packageName] = app.appName;
                                } else {
                                  _selected.remove(app.packageName);
                                }
                              });
                            },
                          ),
                          onTap: () {
                            setState(() {
                              if (checked) {
                                _selected.remove(app.packageName);
                              } else {
                                if (!widget.multiSelect) _selected.clear();
                                _selected[app.packageName] = app.appName;
                              }
                            });
                          },
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.tr('cancel')),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(_selected),
                      child: Text(
                        l10n.tr('confirm', {'selected_length': _selected.length}),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
