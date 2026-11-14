import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/reading_item.dart';
import '../../providers/reading_provider.dart';
import 'reading_goal_sheet.dart';
import 'reading_progress_slider.dart';
import 'reading_sparkline_history.dart';

class ReadingTrackerSheet extends StatefulWidget {
  final int initialTabIndex;

  const ReadingTrackerSheet({
    super.key,
    this.initialTabIndex = 0,
  });

  static Future<void> show(
    BuildContext context, {
    int initialTabIndex = 0,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReadingTrackerSheet(initialTabIndex: initialTabIndex),
    );
  }

  @override
  State<ReadingTrackerSheet> createState() => _ReadingTrackerSheetState();
}

class _ReadingTrackerSheetState extends State<ReadingTrackerSheet>
    with SingleTickerProviderStateMixin {
  static const Color _pippinEmerald = Color(0xFF10B981);
  static const Color _pippinGold = Color(0xFFF59E0B);

  late TabController _tabController;
  bool _showSparklineDrawer = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 3),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddEditBookDialog(BuildContext context, {ReadingItem? existing}) {
    final isEdit = existing != null;
    final titleController = TextEditingController(text: existing?.title ?? '');
    final authorController =
        TextEditingController(text: existing?.author ?? '');
    final totalPagesController = TextEditingController(
      text: (existing?.totalPages ?? 300).toString(),
    );
    final currentPageController = TextEditingController(
      text: (existing?.safeCurrentPage ?? 0).toString(),
    );
    final notesController = TextEditingController(text: existing?.notes ?? '');

    ReadingFormat format = existing?.format ?? ReadingFormat.book;
    String category = existing?.category ?? 'Self-Growth';
    int currentPage = existing?.safeCurrentPage ?? 0;
    int totalPages = existing != null && existing.totalPages > 0
        ? existing.totalPages
        : 300;
    int? rating = existing?.rating;

    const categories = [
      'Self-Growth',
      'Fiction',
      'Tech',
      'Productivity',
      'Creativity',
      'Biography',
      'Science',
      'General',
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final safeTotal = totalPages < 1 ? 1 : totalPages;
            final safeCurrent = currentPage.clamp(0, safeTotal);
            final pct = ((safeCurrent / safeTotal) * 100).round();

            final emeraldText = AppColors.adaptive(
              ctx,
              dark: _pippinEmerald,
              light: const Color(0xFF047857),
            );

            return AlertDialog(
              backgroundColor: AppColors.sheetSurface(ctx),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Text('🦜', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isEdit ? 'Edit Reading Item' : 'Add Book / Reading',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary(ctx),
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      style: TextStyle(
                        color: AppColors.textPrimary(ctx),
                        fontSize: 14,
                      ),
                      decoration: _inputDecoration(
                        ctx,
                        label: 'Title',
                        hint: 'e.g. The Design of Everyday Things',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: authorController,
                      style: TextStyle(
                        color: AppColors.textPrimary(ctx),
                        fontSize: 13,
                      ),
                      decoration: _inputDecoration(
                        ctx,
                        label: 'Author / Creator',
                        hint: 'e.g. Don Norman',
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Pages row + interactive slider inside dialog
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: currentPageController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(
                              color: AppColors.textPrimary(ctx),
                              fontSize: 13,
                            ),
                            decoration: _inputDecoration(
                              ctx,
                              label: 'Current Page',
                              hint: '0',
                            ),
                            onChanged: (val) {
                              final parsed = int.tryParse(val.trim()) ?? 0;
                              setDialogState(() {
                                currentPage = parsed.clamp(0, safeTotal);
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: totalPagesController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(
                              color: AppColors.textPrimary(ctx),
                              fontSize: 13,
                            ),
                            decoration: _inputDecoration(
                              ctx,
                              label: 'Total Pages',
                              hint: '300',
                            ),
                            onChanged: (val) {
                              final parsed = int.tryParse(val.trim()) ?? 1;
                              setDialogState(() {
                                totalPages = parsed.clamp(1, 99999);
                                if (currentPage > totalPages) {
                                  currentPage = totalPages;
                                  currentPageController.text =
                                      currentPage.toString();
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$safeCurrent / $safeTotal pages',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary(ctx),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '$pct%',
                          style: TextStyle(
                            fontSize: 12,
                            color: emeraldText,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(ctx).copyWith(
                        activeTrackColor: _pippinEmerald,
                        inactiveTrackColor: AppColors.trackSurface(ctx),
                        thumbColor: AppColors.isDark(ctx)
                            ? Colors.white
                            : _pippinEmerald,
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 7),
                      ),
                      child: Slider(
                        value: safeCurrent.toDouble(),
                        min: 0.0,
                        max: safeTotal.toDouble(),
                        onChanged: (val) {
                          final rounded = val.round();
                          setDialogState(() {
                            currentPage = rounded;
                            currentPageController.text = rounded.toString();
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Format selector
                    Text(
                      'FORMAT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary(ctx),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: ReadingFormat.values.map((f) {
                        final selected = format == f;
                        return ChoiceChip(
                          label: Text('${f.emoji} ${f.label}'),
                          selected: selected,
                          selectedColor: _pippinEmerald.withValues(alpha: 0.28),
                          backgroundColor: AppColors.elevatedSurface(ctx),
                          labelStyle: TextStyle(
                            color: selected
                                ? emeraldText
                                : AppColors.textPrimary(ctx),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                          onSelected: (v) {
                            if (v) setDialogState(() => format = f);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // Category selector
                    Text(
                      'CATEGORY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary(ctx),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: categories.map((cat) {
                        final selected = category == cat;
                        return ChoiceChip(
                          label: Text(cat),
                          selected: selected,
                          selectedColor: _pippinEmerald.withValues(alpha: 0.28),
                          backgroundColor: AppColors.elevatedSurface(ctx),
                          labelStyle: TextStyle(
                            color: selected
                                ? emeraldText
                                : AppColors.textPrimary(ctx),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                          onSelected: (v) {
                            if (v) setDialogState(() => category = cat);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // Star Rating (optional)
                    Row(
                      children: [
                        Text(
                          'RATING',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary(ctx),
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(width: 8),
                        for (int s = 1; s <= 5; s++)
                          IconButton(
                            icon: Icon(
                              (rating ?? 0) >= s
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: 20,
                              color: (rating ?? 0) >= s
                                  ? _pippinGold
                                  : AppColors.textMuted(ctx),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              setDialogState(() {
                                rating = rating == s ? null : s;
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: notesController,
                      maxLines: 2,
                      style: TextStyle(
                        color: AppColors.textPrimary(ctx),
                        fontSize: 12,
                      ),
                      decoration: _inputDecoration(
                        ctx,
                        label: 'Takeaways / Quotes (optional)',
                        hint: 'Memorable quotes or key insights...',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('Cancel',
                      style: TextStyle(color: AppColors.textSecondary(ctx))),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    if (title.isEmpty) return;

                    final now = DateTime.now();
                    final parsedTotal =
                        (int.tryParse(totalPagesController.text.trim()) ??
                                totalPages)
                            .clamp(1, 99999);
                    final parsedPage =
                        (int.tryParse(currentPageController.text.trim()) ??
                                currentPage)
                            .clamp(0, parsedTotal);

                    final ReadingStatus computedStatus;
                    if (parsedPage >= parsedTotal) {
                      computedStatus = ReadingStatus.finished;
                    } else if (parsedPage > 0) {
                      computedStatus = ReadingStatus.currentlyReading;
                    } else {
                      computedStatus = existing?.status == ReadingStatus.finished
                          ? ReadingStatus.wantToRead
                          : (existing?.status ?? ReadingStatus.wantToRead);
                    }

                    final item = ReadingItem(
                      id: existing?.id ?? const Uuid().v4(),
                      title: title,
                      author: authorController.text.trim(),
                      category: category,
                      format: format,
                      currentPage: parsedPage,
                      totalPages: parsedTotal,
                      status: computedStatus,
                      rating: rating,
                      notes: notesController.text.trim().isNotEmpty
                          ? notesController.text.trim()
                          : null,
                      startedAt: existing?.startedAt,
                      finishedAt: existing?.finishedAt,
                      createdAt: existing?.createdAt ?? now,
                      updatedAt: now,
                    );

                    final provider =
                        Provider.of<ReadingProvider>(context, listen: false);
                    Navigator.of(ctx).pop();

                    if (isEdit) {
                      await provider.updateBook(item);
                    } else {
                      await provider.addBook(item);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pippinEmerald,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    isEdit ? 'Save Changes' : 'Add Book',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  InputDecoration _inputDecoration(
    BuildContext context, {
    required String label,
    required String hint,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: AppColors.textSecondary(context),
        fontSize: 12,
      ),
      hintText: hint,
      hintStyle: TextStyle(
        color: AppColors.textMuted(context),
        fontSize: 12,
      ),
      filled: true,
      fillColor: AppColors.elevatedSurface(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final emeraldText = AppColors.adaptive(
      context,
      dark: _pippinEmerald,
      light: const Color(0xFF047857),
    );
    final goldText = AppColors.adaptive(
      context,
      dark: _pippinGold,
      light: const Color(0xFFB45309),
    );

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.sheetSurface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Consumer<ReadingProvider>(
        builder: (context, provider, _) {
          final allBooks = provider.items;
          final readingBooks = provider.currentlyReadingItems;
          final queueBooks = provider.wantToReadItems;
          final finishedBooks = provider.finishedItems;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _pippinEmerald.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('🦜', style: TextStyle(fontSize: 20)),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reading Progress Tracker',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          Text(
                            'Pippin Reading Sanctuary',
                            style: TextStyle(
                              fontSize: 11,
                              color: emeraldText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Daily Goal & Evening Nudge',
                        icon: Icon(
                          provider.eveningReminderEnabled
                              ? Icons.notifications_active_rounded
                              : Icons.notifications_none_rounded,
                          color: provider.eveningReminderEnabled
                              ? emeraldText
                              : AppColors.textSecondary(context),
                        ),
                        onPressed: () => ReadingGoalSettingsSheet.show(context),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded,
                            color: AppColors.textSecondary(context)),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Library Summary Metrics + expandable 7-Day Goal Sparkline
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.elevatedSurface(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatColumn(
                          context,
                          'Reading',
                          '${provider.currentlyReadingCount}',
                          emeraldText,
                        ),
                        Container(
                            height: 28,
                            width: 1,
                            color: AppColors.border(context)),
                        _buildStatColumn(
                          context,
                          'Today',
                          '${provider.todayPagesRead}/${provider.dailyPageGoal}p',
                          provider.isDailyGoalMet
                              ? emeraldText
                              : AppColors.textPrimary(context),
                        ),
                        Container(
                            height: 28,
                            width: 1,
                            color: AppColors.border(context)),
                        _buildStatColumn(
                          context,
                          'Streak',
                          '🔥 ${provider.currentStreak}d',
                          goldText,
                        ),
                        Container(
                            height: 28,
                            width: 1,
                            color: AppColors.border(context)),
                        _buildStatColumn(
                          context,
                          'Finished',
                          '✅ ${provider.finishedBooksCount}',
                          goldText,
                        ),
                        IconButton(
                          tooltip: 'Toggle 7-Day Sparkline',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 28, minHeight: 28),
                          icon: Icon(
                            _showSparklineDrawer
                                ? Icons.expand_less_rounded
                                : Icons.bar_chart_rounded,
                            size: 18,
                            color: emeraldText,
                          ),
                          onPressed: () => setState(
                            () => _showSparklineDrawer = !_showSparklineDrawer,
                          ),
                        ),
                      ],
                    ),
                    if (_showSparklineDrawer) ...[
                      const SizedBox(height: 10),
                      Divider(height: 1, color: AppColors.border(context)),
                      const SizedBox(height: 10),
                      ReadingSparklineHistory(
                        onConfigureGoal: () =>
                            ReadingGoalSettingsSheet.show(context),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Filter Tabs
              Container(
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.elevatedSurface(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicator: BoxDecoration(
                    color: _pippinEmerald,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.textSecondary(context),
                  labelStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700),
                  tabs: [
                    Tab(text: 'All (${allBooks.length})'),
                    Tab(text: 'Reading (${readingBooks.length})'),
                    Tab(text: 'Queue (${queueBooks.length})'),
                    Tab(text: 'Finished (${finishedBooks.length})'),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Book Lists
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBookList(context, provider, allBooks,
                        emptyTitle: 'Your reading shelf is empty',
                        emptySubtitle:
                            'Tap "+ Add Book / Reading" to track pages and completion.'),
                    _buildBookList(context, provider, readingBooks,
                        emptyTitle: 'Nothing currently being read',
                        emptySubtitle:
                            'Start a book from your Queue or slide its progress!'),
                    _buildBookList(context, provider, queueBooks,
                        emptyTitle: 'Reading queue is clear',
                        emptySubtitle:
                            'Save upcoming books, articles, and guides to read next.'),
                    _buildBookList(context, provider, finishedBooks,
                        emptyTitle: 'No finished books yet',
                        emptySubtitle:
                            'Reach 100% on a book to celebrate and save takeaways!'),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Add Book CTA
              ElevatedButton.icon(
                onPressed: () => _showAddEditBookDialog(context),
                icon: const Icon(Icons.add_rounded,
                    color: Colors.white, size: 20),
                label: const Text(
                  'Add Book / Reading',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _pippinEmerald,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatColumn(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context)),
        ),
      ],
    );
  }

  Widget _buildBookList(
    BuildContext context,
    ReadingProvider provider,
    List<ReadingItem> books, {
    required String emptyTitle,
    required String emptySubtitle,
  }) {
    if (books.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🦜', style: TextStyle(fontSize: 38)),
            const SizedBox(height: 10),
            Text(
              emptyTitle,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                emptySubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: AppColors.textMuted(context)),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: books.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return _buildBookCard(context, provider, books[index]);
      },
    );
  }

  Widget _buildBookCard(
    BuildContext context,
    ReadingProvider provider,
    ReadingItem book,
  ) {
    final statusColor = Color(book.status.colorValue);
    final goldText = AppColors.adaptive(
      context,
      dark: _pippinGold,
      light: const Color(0xFFB45309),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: book.isCompleted
              ? _pippinGold.withValues(alpha: 0.4)
              : AppColors.border(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: format emoji, title/author, status & actions
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  book.format.emoji,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    if (book.author.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        book.author,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${book.status.emoji} ${book.status.label}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.trackSurface(context),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            book.category,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                        ),
                        if (book.rating != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _pippinGold.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '★ ${book.rating}/5',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: goldText,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded,
                    size: 18, color: AppColors.textSecondary(context)),
                color: AppColors.sheetSurface(context),
                onSelected: (value) async {
                  if (value == 'edit') {
                    _showAddEditBookDialog(context, existing: book);
                  } else if (value == 'status_reading') {
                    await provider.setStatus(
                        book.id, ReadingStatus.currentlyReading);
                  } else if (value == 'status_queue') {
                    await provider.setStatus(book.id, ReadingStatus.wantToRead);
                  } else if (value == 'status_finished') {
                    final wasFinished = book.isCompleted;
                    await provider.setStatus(book.id, ReadingStatus.finished);
                    final updated = provider.findById(book.id);
                    if (!wasFinished && updated != null && context.mounted) {
                      showReadingCelebrationDialog(context, updated);
                    }
                  } else if (value == 'delete') {
                    await provider.deleteBook(book.id);
                  }
                },
                itemBuilder: (menuCtx) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit Details',
                        style: TextStyle(
                            color: AppColors.textPrimary(menuCtx),
                            fontSize: 13)),
                  ),
                  PopupMenuItem(
                    value: 'status_reading',
                    child: Text('Mark as Reading',
                        style: TextStyle(
                            color: AppColors.textPrimary(menuCtx),
                            fontSize: 13)),
                  ),
                  PopupMenuItem(
                    value: 'status_queue',
                    child: Text('Move to Queue',
                        style: TextStyle(
                            color: AppColors.textPrimary(menuCtx),
                            fontSize: 13)),
                  ),
                  PopupMenuItem(
                    value: 'status_finished',
                    child: Text('Mark as Finished (100%)',
                        style: TextStyle(
                            color: AppColors.textPrimary(menuCtx),
                            fontSize: 13)),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete Book',
                        style:
                            TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Interactive slider + page count + percentage + quick step controls
          ReadingProgressSlider(book: book, compact: false),

          if (book.notes != null && book.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.sheetSurface(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '"${book.notes!}"',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary(context),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

