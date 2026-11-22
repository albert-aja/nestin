import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/inspiration_models.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../providers/inspiration_provider.dart';
import '../../widgets/inspiration/inspiration_notification_sheet.dart';
import 'quote_card_studio_screen.dart';

enum InspirationSectionTab { browse, favorites, myQuotes, submissions }

class InspirationScreen extends StatefulWidget {
  final InspirationSectionTab initialTab;

  const InspirationScreen({
    super.key,
    this.initialTab = InspirationSectionTab.browse,
  });

  @override
  State<InspirationScreen> createState() => _InspirationScreenState();
}

class _InspirationScreenState extends State<InspirationScreen> {
  late InspirationSectionTab _tab;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<InspirationProvider>();
      if (!provider.hasLoadedOnce) {
        provider.initialize(locale: context.l10n.isIndonesian ? 'id' : 'en');
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openCreateOrEditPersonalQuoteSheet({
    InspirationUserQuote? existing,
  }) async {
    final l10n = context.l10n;
    final provider = context.read<InspirationProvider>();
    final categories = provider.categories;
    if (categories.isEmpty) return;

    final quoteCtrl = TextEditingController(text: existing?.quoteText ?? '');
    final authorCtrl = TextEditingController(text: existing?.authorName ?? '');
    final sourceCtrl =
        TextEditingController(text: existing?.sourceReference ?? '');
    var selectedCategory = categories.firstWhere(
      (c) => c.id == existing?.categoryId,
      orElse: () => categories.first,
    );
    var selectedLocale = existing?.locale ?? (l10n.isIndonesian ? 'id' : 'en');
    var displayPref = existing?.displayPreference ?? 'anonymous';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.sheetSurface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      existing == null
                          ? l10n.tr('create_personal_quote')
                          : l10n.tr('edit_quote'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: quoteCtrl,
                      maxLines: 4,
                      maxLength: 500,
                      decoration: InputDecoration(
                        labelText: l10n.tr('quote_text'),
                        hintText: l10n.tr('write_a_calm_reflection_or_reminder'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: authorCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.tr('author_attribution_optional'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: sourceCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.tr('source_book_optional'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<InspirationCategory>(
                      initialValue: selectedCategory,
                      decoration: InputDecoration(
                        labelText: l10n.tr('category'),
                        border: const OutlineInputBorder(),
                      ),
                      items: categories
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(
                                c.labelForLocale(l10n.isIndonesian ? 'id' : 'en'),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() => selectedCategory = val);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('English'),
                            selected: selectedLocale == 'en',
                            onSelected: (_) =>
                                setSheetState(() => selectedLocale = 'en'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Bahasa Indonesia'),
                            selected: selectedLocale == 'id',
                            onSelected: (_) =>
                                setSheetState(() => selectedLocale = 'id'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        l10n.tr('publish_anonymously_if_shared_globally'),
                        style: const TextStyle(fontSize: 13),
                      ),
                      value: displayPref == 'anonymous',
                      onChanged: (val) => setSheetState(() {
                        displayPref = val ? 'anonymous' : 'username';
                      }),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          final text = quoteCtrl.text.trim();
                          if (text.length < 5) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  l10n.tr('quote_must_be_at_least_5'),
                                ),
                              ),
                            );
                            return;
                          }
                          if (existing == null) {
                            await provider.createPersonalQuote(
                              quoteText: text,
                              authorName: authorCtrl.text,
                              category: selectedCategory,
                              locale: selectedLocale,
                              sourceReference: sourceCtrl.text,
                              displayPreference: displayPref,
                            );
                          } else {
                            await provider.updatePersonalQuote(
                              existing,
                              quoteText: text,
                              authorName: authorCtrl.text,
                              category: selectedCategory,
                              displayPreference: displayPref,
                            );
                          }
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          if (mounted) {
                            setState(() => _tab = InspirationSectionTab.myQuotes);
                          }
                        },
                        child: Text(l10n.tr('save_quote')),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openSubmitDialog(InspirationUserQuote quote) async {
    final l10n = context.l10n;
    final provider = context.read<InspirationProvider>();
    var anonymousPub = quote.displayPreference == 'anonymous';
    var rightsConfirmed = quote.rightsConfirmed;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            l10n.tr('submit_for_global_review'),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '“${quote.quoteText}”',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  l10n.tr('publish_anonymously_recommended'),
                  style: const TextStyle(fontSize: 13),
                ),
                value: anonymousPub,
                onChanged: (v) =>
                    setDialogState(() => anonymousPub = v ?? true),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  l10n.tr('i_confirm_this_quote_is_original'),
                  style: const TextStyle(fontSize: 13),
                ),
                value: rightsConfirmed,
                onChanged: (v) =>
                    setDialogState(() => rightsConfirmed = v ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.tr('cancel')),
            ),
            FilledButton(
              onPressed: rightsConfirmed
                  ? () => Navigator.of(ctx).pop(true)
                  : null,
              child: Text(l10n.tr('submit')),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    final res = await provider.submitQuoteGlobally(
      quote: quote,
      anonymousPublication: anonymousPub,
      rightsConfirmed: true,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          res.isSuccess
              ? l10n.tr('submitted_for_moderator_review')
              : (res.errorMessage ?? 'Unable to submit'),
        ),
      ),
    );
    if (res.isSuccess || res.isOfflineOrUnconfigured) {
      setState(() => _tab = InspirationSectionTab.submissions);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = context.watch<InspirationProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tr('inspiration')),
        actions: [
          IconButton(
            tooltip: l10n.tr('notification_settings'),
            icon: Icon(
              provider.notificationPreferences.dailyEnabled
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_none_rounded,
              color: provider.notificationPreferences.dailyEnabled
                  ? AppColors.accent
                  : null,
            ),
            onPressed: () => InspirationNotificationSheet.show(context),
          ),
          IconButton(
            tooltip: l10n.tr('create_personal_quote_2'),
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _openCreateOrEditPersonalQuoteSheet(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Section Navigation Pills
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _tabChip(
                    context,
                    InspirationSectionTab.browse,
                    l10n.tr('browse'),
                    Icons.explore_outlined,
                  ),
                  const SizedBox(width: 8),
                  _tabChip(
                    context,
                    InspirationSectionTab.favorites,
                    l10n.tr('favorites', {'provider_length': provider.favorites.length}),
                    Icons.bookmark_rounded,
                  ),
                  const SizedBox(width: 8),
                  _tabChip(
                    context,
                    InspirationSectionTab.myQuotes,
                    l10n.tr('my_quotes'),
                    Icons.edit_note_rounded,
                  ),
                  const SizedBox(width: 8),
                  _tabChip(
                    context,
                    InspirationSectionTab.submissions,
                    l10n.tr('submissions'),
                    Icons.outbox_rounded,
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: switch (_tab) {
              InspirationSectionTab.browse => _buildBrowseView(context, provider),
              InspirationSectionTab.favorites =>
                _buildFavoritesView(context, provider),
              InspirationSectionTab.myQuotes =>
                _buildMyQuotesView(context, provider),
              InspirationSectionTab.submissions =>
                _buildSubmissionsView(context, provider),
            },
          ),
        ],
      ),
    );
  }

  Widget _tabChip(
    BuildContext context,
    InspirationSectionTab target,
    String label,
    IconData icon,
  ) {
    final selected = _tab == target;
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 16,
        color: selected ? Colors.white : AppColors.textSecondary(context),
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : AppColors.textPrimary(context),
        ),
      ),
      selected: selected,
      selectedColor: AppColors.primary,
      onSelected: (_) => setState(() => _tab = target),
    );
  }

  Widget _buildBrowseView(
    BuildContext context,
    InspirationProvider provider,
  ) {
    final l10n = context.l10n;
    final locale = l10n.isIndonesian ? 'id' : 'en';
    final featured = provider.featuredQuote;
    final quotes = provider.quotes;

    return RefreshIndicator(
      onRefresh: () => provider.initialize(locale: locale),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          // Daily Featured Quote Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: AppColors.isDark(context)
                    ? const [Color(0xFF281927), Color(0xFF1A1B24)]
                    : const [Color(0xFFFFEFE6), Color(0xFFFFFFFF)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        l10n.tr('daily_featured'),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (featured.scheduledFor != null)
                      Text(
                        featured.scheduledFor!,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    const Spacer(),
                    if (provider.isFromCache)
                      Chip(
                        label: Text(
                          l10n.tr('offline_cache'),
                          style: const TextStyle(fontSize: 10),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '“${featured.quoteText}”',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '— ${featured.author}${featured.sourceReference != null ? ' • ${featured.sourceReference}' : ''}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => provider.toggleFavorite(featured),
                      icon: Icon(
                        provider.isFavorite(featured.id)
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        size: 18,
                      ),
                      label: Text(
                        provider.isFavorite(featured.id)
                            ? l10n.tr('saved')
                            : l10n.tr('save'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => QuoteCardStudioScreen(
                              quoteText: featured.quoteText,
                              authorName: featured.author,
                              initialMascotDomain: featured.mascotDomain,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.palette_rounded, size: 18),
                        label: Text(
                          l10n.tr('open_quote_card'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Search + Language + Favorites Quick Filter
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: l10n.tr('search_quotes_authors_themes'),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _searchController.clear();
                        provider.applyFilters(search: '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.cardSurface(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.border(context)),
              ),
            ),
            onSubmitted: (val) => provider.applyFilters(search: val),
            onChanged: (val) => provider.applyFilters(search: val),
          ),
          const SizedBox(height: 10),

          // Category Filter Chips (Admin-managed)
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(l10n.tr('all_topics')),
                    selected: provider.selectedCategorySlug == null &&
                        !provider.favoritesOnlyFilter,
                    onSelected: (_) => provider.applyFilters(
                      clearCategory: true,
                      favoritesOnly: false,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(l10n.tr('saved_only')),
                    selected: provider.favoritesOnlyFilter,
                    onSelected: (v) => provider.applyFilters(favoritesOnly: v),
                  ),
                ),
                ...provider.categories.map(
                  (cat) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cat.labelForLocale(locale)),
                      selected: provider.selectedCategorySlug == cat.slug,
                      onSelected: (_) => provider.applyFilters(
                        categorySlug: cat.slug,
                        favoritesOnly: false,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Language & Author Filters
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(l10n.tr('all_lang')),
                    selected: provider.selectedLocale == null,
                    onSelected: (_) => provider.applyFilters(clearLocale: true),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: const Text('EN'),
                    selected: provider.selectedLocale == 'en',
                    onSelected: (_) => provider.applyFilters(locale: 'en'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: ChoiceChip(
                    label: const Text('ID'),
                    selected: provider.selectedLocale == 'id',
                    onSelected: (_) => provider.applyFilters(locale: 'id'),
                  ),
                ),
                ...provider.authors.map(
                  (author) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(author.name),
                      selected: provider.selectedAuthor == author.name,
                      onSelected: (sel) => provider.applyFilters(
                        author: sel ? author.name : null,
                        clearAuthor: !sel,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (provider.isLoading && quotes.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (quotes.isEmpty)
            _emptyState(
              context,
              l10n.tr('no_matching_quotes_found_for_these'),
            )
          else
            ...quotes.map((q) => _quoteCardTile(context, provider, q)),

          if (provider.hasMore)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton(
                onPressed: provider.isLoading ? null : provider.loadMoreQuotes,
                child: Text(l10n.tr('load_more_quotes')),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFavoritesView(
    BuildContext context,
    InspirationProvider provider,
  ) {
    final l10n = context.l10n;
    final items = provider.filteredFavorites;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: l10n.tr('search_saved_quotes'),
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: AppColors.cardSurface(context),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onChanged: (val) => provider.applyFilters(search: val),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          _emptyState(
            context,
            l10n.tr('bookmark_quotes_to_keep_a_calm'),
          )
        else
          ...items.map((q) => _quoteCardTile(context, provider, q)),
      ],
    );
  }

  Widget _buildMyQuotesView(
    BuildContext context,
    InspirationProvider provider,
  ) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!provider.hasSignedInAccount)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              l10n.tr('guest_mode_saves_personal_quotes_locally'),
              style: const TextStyle(fontSize: 12),
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => _openCreateOrEditPersonalQuoteSheet(),
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.tr('new_personal_quote')),
          ),
        ),
        const SizedBox(height: 14),
        if (provider.userQuotes.isEmpty)
          _emptyState(
            context,
            l10n.tr('create_personal_reminders_or_reflections_turn'),
          )
        else
          ...provider.userQuotes.map((uq) {
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Chip(
                          label: Text(uq.categorySlug),
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(width: 6),
                        Chip(
                          label: Text(
                            uq.isLocalOnlyDraft
                                ? l10n.tr('local_draft')
                                : l10n.tr('cloud_synced'),
                            style: const TextStyle(fontSize: 10),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '“${uq.quoteText}”',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (uq.authorName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '— ${uq.authorName}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => QuoteCardStudioScreen(
                                quoteText: uq.quoteText,
                                authorName: uq.authorName ?? 'Personal Note',
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.palette_outlined, size: 16),
                          label: Text(l10n.tr('card')),
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              _openCreateOrEditPersonalQuoteSheet(existing: uq),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: Text(l10n.tr('edit')),
                        ),
                        TextButton.icon(
                          onPressed: () => _openSubmitDialog(uq),
                          icon: const Icon(Icons.publish_rounded, size: 16),
                          label: Text(
                            l10n.tr('submit_globally'),
                          ),
                        ),
                        TextButton(
                          onPressed: () => provider.deletePersonalQuote(uq.id),
                          child: Text(
                            l10n.tr('delete'),
                            style: const TextStyle(color: AppColors.error),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildSubmissionsView(
    BuildContext context,
    InspirationProvider provider,
  ) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (provider.submissions.isEmpty)
          _emptyState(
            context,
            l10n.tr('no_global_submissions_yet_submitted_personal'),
          )
        else
          ...provider.submissions.map((sub) {
            final statusColor = switch (sub.status) {
              InspirationSubmissionStatus.approved => AppColors.success,
              InspirationSubmissionStatus.rejected => AppColors.error,
              InspirationSubmissionStatus.pending => AppColors.accent,
              InspirationSubmissionStatus.withdrawn => AppColors.textMuted(context),
              InspirationSubmissionStatus.draft => AppColors.textSecondary(context),
            };
            final statusLabel = !sub.isConfirmedByServer
                ? l10n.tr('offline_draft_not_submitted')
                : sub.status.toApi();

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          sub.categorySlug,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '“${sub.quoteText}”',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (sub.rejectionReason != null &&
                        sub.rejectionReason!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${l10n.tr('moderator_note')}: ${sub.rejectionReason}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                    if (sub.status == InspirationSubmissionStatus.pending) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => provider.withdrawSubmission(sub.id),
                          icon: const Icon(Icons.undo_rounded, size: 16),
                          label: Text(l10n.tr('withdraw')),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _quoteCardTile(
    BuildContext context,
    InspirationProvider provider,
    InspirationQuote q,
  ) {
    final l10n = context.l10n;
    final isFav = provider.isFavorite(q.id);
    final isHighlighted = provider.highlightedQuoteId == q.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isHighlighted ? AppColors.primary : AppColors.border(context),
          width: isHighlighted ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(
                  label: Text(
                    q.category,
                    style: const TextStyle(fontSize: 10),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 6),
                Text(
                  q.locale.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted(context),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: l10n.tr('save_favorite'),
                  icon: Icon(
                    isFav
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: isFav
                        ? AppColors.accent
                        : AppColors.textSecondary(context),
                  ),
                  onPressed: () => provider.toggleFavorite(q),
                ),
                IconButton(
                  tooltip: l10n.tr('open_card_studio'),
                  icon: const Icon(Icons.palette_outlined),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => QuoteCardStudioScreen(
                        quoteText: q.quoteText,
                        authorName: q.author,
                        initialMascotDomain: q.mascotDomain,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.tr('copy_quote'),
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: '“${q.quoteText}” — ${q.author}'),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          l10n.tr('quote_copied'),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            Text(
              '“${q.quoteText}”',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.4,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '— ${q.author}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary(context),
          ),
        ),
      ),
    );
  }
}
