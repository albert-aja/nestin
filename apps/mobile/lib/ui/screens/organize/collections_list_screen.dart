import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/collection_item.dart';
import '../../../providers/collection_provider.dart';

class CollectionsListScreen extends StatefulWidget {
  const CollectionsListScreen({super.key});

  @override
  State<CollectionsListScreen> createState() => _CollectionsListScreenState();
}

class _CollectionsListScreenState extends State<CollectionsListScreen> {
  bool _onlyReusableFilter = false;

  void _showAddCollectionDialog(BuildContext context) {
    final l10n = context.l10n;
    final titleController = TextEditingController();
    final descController = TextEditingController();
    var isReusable = false;
    var selectedIcon = Icons.list_rounded;
    var selectedColor = 0xFF3A86FF;
    String? selectedTemplateKey;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) => Container(
            padding: EdgeInsets.only(
              top: 20,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            decoration: BoxDecoration(
              color: AppColors.sheetSurface(ctx),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.pick('New Custom List', 'Daftar Baru'),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.pick(
                      'Start Blank or From a Packing Preset',
                      'Mulai Kosong atau Dari Template Kemas',
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary(ctx),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ChoiceChip(
                        selected: selectedTemplateKey == null,
                        label: Text(l10n.pick('Blank', 'Kosong')),
                        onSelected: (_) {
                          setSheetState(() => selectedTemplateKey = null);
                        },
                      ),
                      ...TravelPackingTemplates.presets.map((spec) {
                        final isSelected = selectedTemplateKey == spec.key;
                        return ChoiceChip(
                          selected: isSelected,
                          avatar: Icon(
                            spec.icon,
                            size: 15,
                            color: Color(spec.colorValue),
                          ),
                          label: Text(spec.title),
                          onSelected: (_) {
                            setSheetState(() {
                              selectedTemplateKey = spec.key;
                              isReusable = true;
                              selectedIcon = spec.icon;
                              selectedColor = spec.colorValue;
                              if (titleController.text.trim().isEmpty) {
                                titleController.text = spec.title;
                              }
                            });
                          },
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: l10n.pick(
                        'List Title (e.g. Bali Weekend Trip, Gear)',
                        'Judul Daftar (cth. Liburan Akhir Pekan, Perlengkapan)',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (selectedTemplateKey == null) ...[
                    TextField(
                      controller: descController,
                      decoration: InputDecoration(
                        labelText: l10n.pick(
                          'Description (Optional)',
                          'Deskripsi (Opsional)',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: isReusable,
                    title: Text(
                      l10n.pick(
                        'Reusable Travel / Packing Checklist',
                        'Daftar Kemas / Perjalanan Berulang',
                      ),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      l10n.pick(
                        'Shows 1-tap Uncheck All & Reuse counter on this card',
                        'Tampilkan tombol Reset Semua & penghitung pakai ulang',
                      ),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary(ctx),
                      ),
                    ),
                    onChanged: (v) => setSheetState(() => isReusable = v),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () async {
                      final provider = Provider.of<CollectionProvider>(
                        context,
                        listen: false,
                      );
                      final t = titleController.text.trim();
                      if (selectedTemplateKey != null) {
                        final created = await provider.createFromPackingTemplate(
                          selectedTemplateKey!,
                          customTitle: t,
                          markReusable: isReusable,
                        );
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        if (context.mounted) {
                          _showSnack(
                            context,
                            l10n.pick(
                              'Created "${created.title}" (${created.totalCount} items)',
                              'Membuat "${created.title}" (${created.totalCount} item)',
                            ),
                          );
                        }
                        return;
                      }
                      if (t.isNotEmpty) {
                        await provider.addCollection(
                          CollectionItem(
                            id: const Uuid().v4(),
                            title: t,
                            description: descController.text.trim(),
                            iconCodePoint: selectedIcon.codePoint,
                            colorValue: selectedColor,
                            isReusableTemplate: isReusable,
                            createdAt: DateTime.now(),
                          ),
                        );
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      selectedTemplateKey != null
                          ? l10n.pick('Add Packing List', 'Tambah Daftar Kemas')
                          : l10n.pick('Create List', 'Buat Daftar'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showTemplatePreviewSheet(
    BuildContext context,
    PackingTemplateSpec spec,
  ) {
    final l10n = context.l10n;
    final titleCtrl = TextEditingController(text: spec.title);
    final accent = Color(spec.colorValue);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.82,
          ),
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: AppColors.sheetSurface(ctx),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(spec.icon, color: accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          spec.title,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          spec.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary(ctx),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  labelText: l10n.pick('Trip / List Name', 'Nama Perjalanan'),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.pick(
                  'Included Items (${spec.items.length})',
                  'Item Termasuk (${spec.items.length})',
                ),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary(ctx),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: spec.items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (_, idx) {
                    final item = spec.items[idx];
                    return Row(
                      children: [
                        Icon(
                          Icons.check_box_outline_blank_rounded,
                          size: 16,
                          color: accent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.text,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.category,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  final provider = Provider.of<CollectionProvider>(
                    context,
                    listen: false,
                  );
                  final created = await provider.createFromPackingTemplate(
                    spec.key,
                    customTitle: titleCtrl.text.trim(),
                  );
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (context.mounted) {
                    _showSnack(
                      context,
                      l10n.pick(
                        'Added "${created.title}" (${created.totalCount} items)',
                        'Menambahkan "${created.title}" (${created.totalCount} item)',
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.add_task_rounded, size: 18),
                label: Text(
                  l10n.pick('Add Packing List', 'Tambah Daftar Kemas'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDuplicateDialog(BuildContext context, CollectionItem source) {
    final l10n = context.l10n;
    final titleCtrl = TextEditingController(text: '${source.title} (Copy)');
    var resetChecks = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.cardSurface(ctx),
          title: Text(
            l10n.pick('Duplicate Template / List', 'Duplikat Template / Daftar'),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.pick('New Trip / List Name', 'Nama Daftar Baru'),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: resetChecks,
                title: Text(
                  l10n.pick(
                    'Start all items unchecked',
                    'Mulai dengan semua item belum dicentang',
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
                onChanged: (v) => setDialogState(() => resetChecks = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.pick('Cancel', 'Batal')),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final provider = Provider.of<CollectionProvider>(
                  context,
                  listen: false,
                );
                final copy = await provider.duplicateCollection(
                  source.id,
                  customTitle: titleCtrl.text.trim(),
                  resetChecks: resetChecks,
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (context.mounted && copy != null) {
                  _showSnack(
                    context,
                    l10n.pick(
                      'Duplicated as "${copy.title}"',
                      'Diduplikasi menjadi "${copy.title}"',
                    ),
                  );
                }
              },
              icon: const Icon(Icons.copy_all_rounded, size: 16),
              label: Text(l10n.pick('Duplicate', 'Duplikat')),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddEntryDialog(BuildContext context, String collectionId) {
    final l10n = context.l10n;
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.pick('Add Entry', 'Tambah Item')),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.pick('Item name...', 'Nama item...'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.pick('Cancel', 'Batal')),
          ),
          ElevatedButton(
            onPressed: () {
              final text = textController.text.trim();
              if (text.isNotEmpty) {
                Provider.of<CollectionProvider>(context, listen: false)
                    .addEntryToCollection(collectionId, text);
                Navigator.of(ctx).pop();
              }
            },
            child: Text(l10n.pick('Add', 'Tambah')),
          ),
        ],
      ),
    );
  }

  void _showSnack(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = Provider.of<CollectionProvider>(context);
    final allCollections = provider.collections;
    final collections = _onlyReusableFilter
        ? provider.reusableCollections
        : allCollections;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 92),
        children: [
          _buildPackingTemplatesCard(context, provider),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ChoiceChip(
                selected: !_onlyReusableFilter,
                label: Text(
                  l10n.pick(
                    'All Lists (${allCollections.length})',
                    'Semua Daftar (${allCollections.length})',
                  ),
                ),
                onSelected: (_) => setState(() => _onlyReusableFilter = false),
              ),
              ChoiceChip(
                selected: _onlyReusableFilter,
                avatar: const Icon(Icons.luggage_rounded, size: 15),
                label: Text(
                  l10n.pick(
                    'Packing & Reusable (${provider.reusableCollections.length})',
                    'Kemas & Berulang (${provider.reusableCollections.length})',
                  ),
                ),
                onSelected: (_) => setState(() => _onlyReusableFilter = true),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (collections.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.luggage_rounded,
                      size: 36,
                      color: AppColors.textSecondary(context),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _onlyReusableFilter
                          ? l10n.pick(
                              'No reusable packing checklists yet. Tap a preset above to add one in 1 tap.',
                              'Belum ada daftar kemas berulang. Ketuk template di atas untuk menambah.',
                            )
                          : l10n.pick(
                              'No lists yet. Create one or pick a packing template above.',
                              'Belum ada daftar. Buat baru atau pilih template kemas di atas.',
                            ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...collections.map(
              (col) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _buildCollectionCard(context, provider, col),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCollectionDialog(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          l10n.pick('New List', 'Daftar Baru'),
          style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildPackingTemplatesCard(
    BuildContext context,
    CollectionProvider provider,
  ) {
    final l10n = context.l10n;
    final presets = provider.availablePackingTemplates;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.luggage_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.pick(
                          'Travel & Packing Templates',
                          'Template Kemas & Perjalanan',
                        ),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        l10n.pick(
                          'Reusable presets • Tap to preview or + for 1-tap add',
                          'Template berulang • Ketuk pratinjau atau + untuk tambah cepat',
                        ),
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
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: presets.map((spec) {
                final accent = Color(spec.colorValue);
                return InkWell(
                  onTap: () => _showTemplatePreviewSheet(context, spec),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 7, 6, 7),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(spec.icon, size: 16, color: accent),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            spec.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(${spec.items.length})',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () async {
                            final created = await provider
                                .createFromPackingTemplate(spec.key);
                            if (!context.mounted) return;
                            _showSnack(
                              context,
                              l10n.pick(
                                'Added "${created.title}" packing checklist',
                                'Daftar kemas "${created.title}" ditambahkan',
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Semantics(
                            button: true,
                            label: 'Add ${spec.title}',
                            child: Tooltip(
                              message: 'Use ${spec.title} Template',
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.add_circle_rounded,
                                  size: 18,
                                  color: accent,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectionCard(
    BuildContext context,
    CollectionProvider provider,
    CollectionItem col,
  ) {
    final l10n = context.l10n;
    final accent = Color(col.colorValue);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(col.displayIcon, color: accent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        col.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (col.description.isNotEmpty)
                        Text(
                          col.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _miniBadge(
                            '${col.checkedCount}/${col.totalCount}',
                            col.isAllChecked ? AppColors.success : accent,
                          ),
                          if (col.isReusableTemplate)
                            _miniBadge(
                              l10n.pick('Reusable', 'Berulang'),
                              AppColors.primary,
                              icon: Icons.repeat_rounded,
                            ),
                          if (col.reuseCount > 0)
                            _miniBadge(
                              l10n.pick(
                                'Reused ${col.reuseCount}x',
                                'Dipakai ${col.reuseCount}x',
                              ),
                              AppColors.success,
                              icon: Icons.history_rounded,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.add_circle_outline_rounded,
                    color: AppColors.adaptive(
                      context,
                      dark: AppColors.accent,
                      light: const Color(0xFFB45309),
                    ),
                  ),
                  tooltip: l10n.pick('Add Entry', 'Tambah Item'),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _showAddEntryDialog(context, col.id),
                ),
                PopupMenuButton<String>(
                  tooltip: l10n.pick('List options', 'Opsi daftar'),
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 19,
                    color: AppColors.textSecondary(context),
                  ),
                  onSelected: (value) async {
                    if (value == 'toggle_reusable') {
                      await provider.toggleReusableTemplate(col.id);
                    } else if (value == 'duplicate') {
                      if (context.mounted) _showDuplicateDialog(context, col);
                    } else if (value == 'delete') {
                      await provider.deleteCollection(col.id);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'duplicate',
                      child: Row(
                        children: [
                          const Icon(Icons.copy_all_rounded, size: 17),
                          const SizedBox(width: 8),
                          Text(l10n.pick('Duplicate List', 'Duplikat Daftar')),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle_reusable',
                      child: Row(
                        children: [
                          const Icon(Icons.repeat_rounded, size: 17),
                          const SizedBox(width: 8),
                          Text(
                            col.isReusableTemplate
                                ? l10n.pick('Unmark Reusable', 'Hapus Tanda Berulang')
                                : l10n.pick('Mark as Reusable', 'Tandai Berulang'),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete_outline_rounded, size: 17),
                          const SizedBox(width: 8),
                          Text(l10n.pick('Delete List', 'Hapus Daftar')),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Progress Bar
            if (col.totalCount > 0) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: col.progress,
                  minHeight: 5,
                  backgroundColor: AppColors.trackSurface(context),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    col.isAllChecked ? AppColors.success : accent,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Entries
            if (col.entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  l10n.pick(
                    'No items yet. Tap + to add items.',
                    'Belum ada item. Ketuk + untuk menambah.',
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              )
            else
              ...col.entries.map((entry) => InkWell(
                    onTap: () => provider.toggleEntryCheck(col.id, entry.id),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            entry.isChecked
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 18,
                            color: entry.isChecked
                                ? AppColors.success
                                : AppColors.textSecondary(context),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              entry.text,
                              style: TextStyle(
                                fontSize: 13,
                                decoration: entry.isChecked
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: entry.isChecked
                                    ? AppColors.textSecondary(context)
                                    : AppColors.textPrimary(context),
                              ),
                            ),
                          ),
                          if (entry.category != null &&
                              entry.category!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                entry.category!,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary(context),
                                ),
                              ),
                            ),
                          ],
                          InkWell(
                            onTap: () => provider.removeEntryFromCollection(
                              col.id,
                              entry.id,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            child: Tooltip(
                              message: l10n.pick('Remove item', 'Hapus item'),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 14,
                                  color: AppColors.textSecondary(context),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),

            const SizedBox(height: 8),
            Divider(height: 1, color: AppColors.border(context)),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (col.entries.isNotEmpty)
                    TextButton(
                      onPressed: () async {
                        final hadChecks = col.hasCheckedEntries;
                        await provider.uncheckAllEntries(col.id);
                        if (!context.mounted) return;
                        _showSnack(
                          context,
                          hadChecks
                              ? l10n.pick(
                                  'Reset "${col.title}" for next trip!',
                                  '"${col.title}" direset untuk perjalanan berikutnya!',
                                )
                              : l10n.pick(
                                  'All items already unchecked & ready!',
                                  'Semua item sudah kosong & siap dipakai!',
                                ),
                        );
                      },
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.restart_alt_rounded,
                            size: 16,
                            color: col.hasCheckedEntries
                                ? accent
                                : AppColors.textSecondary(context),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              l10n.pick(
                                'Uncheck All / Reuse for Next Trip',
                                'Reset Semua / Pakai Ulang Nanti',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: col.hasCheckedEntries
                                    ? accent
                                    : AppColors.textSecondary(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  TextButton.icon(
                    onPressed: () => _showDuplicateDialog(context, col),
                    icon: const Icon(Icons.copy_all_rounded, size: 15),
                    label: Text(
                      l10n.pick('Duplicate', 'Duplikat'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniBadge(String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
