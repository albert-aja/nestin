import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/reading_item.dart';
import '../../providers/reading_provider.dart';

const Color _pippinEmerald = Color(0xFF10B981);
const Color _pippinGold = Color(0xFFF59E0B);

/// Shared interactive slider + quick-step controls for updating reading pages.
class ReadingProgressSlider extends StatefulWidget {
  final ReadingItem book;
  final bool compact;

  const ReadingProgressSlider({
    super.key,
    required this.book,
    this.compact = false,
  });

  @override
  State<ReadingProgressSlider> createState() => _ReadingProgressSliderState();
}

class _ReadingProgressSliderState extends State<ReadingProgressSlider> {
  bool? _wasCompletedBeforeDrag;

  @override
  Widget build(BuildContext context) {
    final book = widget.book;
    final provider = Provider.of<ReadingProvider>(context, listen: false);
    final hasPages = book.totalPages > 0;
    final maxSlider = hasPages ? book.totalPages.toDouble() : 1.0;
    final sliderValue = book.safeCurrentPage.toDouble().clamp(0.0, maxSlider);
    final activeColor = book.isCompleted ? _pippinGold : _pippinEmerald;

    final stepDeltas = widget.compact
        ? const [-5, 5, 10]
        : const [-10, -1, 1, 10, 25];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Page count + remaining + percentage badge row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: InkWell(
                onTap: () => showSetReadingPageDialog(context, book),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.elevatedSurface(context),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border(context)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.menu_book_rounded,
                        size: 13,
                        color: activeColor,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Page ${book.safeCurrentPage} / ${book.totalPages}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary(context),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.edit_rounded,
                        size: 11,
                        color: AppColors.textSecondary(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  book.isCompleted
                      ? 'Completed!'
                      : '${book.pagesRemaining} left',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: book.isCompleted
                        ? AppColors.adaptive(
                            context,
                            dark: _pippinGold,
                            light: const Color(0xFFB45309),
                          )
                        : AppColors.textSecondary(context),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: activeColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: activeColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    book.formattedPercentage,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.adaptive(
                        context,
                        dark: activeColor,
                        light: book.isCompleted
                            ? const Color(0xFFB45309)
                            : const Color(0xFF047857),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 2),

        // Interactive progress slider
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: activeColor,
            inactiveTrackColor: AppColors.trackSurface(context),
            thumbColor: AppColors.isDark(context) ? Colors.white : activeColor,
            overlayColor: activeColor.withValues(alpha: 0.22),
            trackHeight: widget.compact ? 5 : 6,
            thumbShape: RoundSliderThumbShape(
              enabledThumbRadius: widget.compact ? 7 : 8,
            ),
            overlayShape: RoundSliderOverlayShape(
              overlayRadius: widget.compact ? 14 : 16,
            ),
          ),
          child: Slider(
            value: sliderValue,
            min: 0.0,
            max: maxSlider,
            onChangeStart: hasPages
                ? (_) {
                    _wasCompletedBeforeDrag = book.isCompleted;
                  }
                : null,
            onChanged: hasPages
                ? (val) {
                    provider.updatePageProgress(
                      book.id,
                      val.round(),
                      persist: false,
                    );
                  }
                : null,
            onChangeEnd: hasPages
                ? (val) async {
                    final wasCompleted = _wasCompletedBeforeDrag ?? false;
                    _wasCompletedBeforeDrag = null;
                    await provider.updatePageProgress(
                      book.id,
                      val.round(),
                      persist: true,
                    );
                    final updated = provider.findById(book.id);
                    if (context.mounted &&
                        !wasCompleted &&
                        updated != null &&
                        updated.isCompleted) {
                      HapticFeedback.mediumImpact();
                      showReadingCelebrationDialog(context, updated);
                    }
                  }
                : null,
          ),
        ),

        // Quick page increment/decrement controls
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: stepDeltas.map((delta) {
            final isNegative = delta < 0;
            final canStep = hasPages &&
                (isNegative
                    ? book.safeCurrentPage > 0
                    : book.safeCurrentPage < book.totalPages);
            final label = delta > 0 ? '+$delta' : '$delta';
            final chipColor = isNegative
                ? AppColors.textSecondary(context)
                : AppColors.adaptive(
                    context,
                    dark: activeColor,
                    light: book.isCompleted
                        ? const Color(0xFFB45309)
                        : const Color(0xFF047857),
                  );

            return OutlinedButton(
              onPressed: canStep
                  ? () async {
                      HapticFeedback.selectionClick();
                      final justFinished =
                          await provider.incrementPages(book.id, delta);
                      final updated = provider.findById(book.id);
                      if (justFinished && updated != null && context.mounted) {
                        HapticFeedback.mediumImpact();
                        showReadingCelebrationDialog(context, updated);
                      }
                    }
                  : null,
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: canStep
                      ? chipColor.withValues(alpha: 0.35)
                      : AppColors.border(context),
                ),
                backgroundColor: AppColors.elevatedSurface(context),
                padding: EdgeInsets.symmetric(
                  horizontal: widget.compact ? 9 : 10,
                  vertical: 4,
                ),
                minimumSize: const Size(0, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                '$label p',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: canStep ? chipColor : AppColors.textMuted(context),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

Future<void> showSetReadingPageDialog(
  BuildContext context,
  ReadingItem book,
) async {
  final pageController =
      TextEditingController(text: book.safeCurrentPage.toString());
  final totalController =
      TextEditingController(text: book.totalPages.toString());

  await showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          final parsedTotal =
              (int.tryParse(totalController.text.trim()) ?? book.totalPages)
                  .clamp(1, 99999);
          final parsedPage =
              (int.tryParse(pageController.text.trim()) ?? 0)
                  .clamp(0, parsedTotal);
          final previewPct = ((parsedPage / parsedTotal) * 100).round();

          return AlertDialog(
            backgroundColor: AppColors.sheetSurface(context),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Text(book.format.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Update Progress',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(context),
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
                  Text(
                    book.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: pageController,
                          keyboardType: TextInputType.number,
                          autofocus: true,
                          style: TextStyle(
                              color: AppColors.textPrimary(context),
                              fontSize: 14,
                              fontWeight: FontWeight.w700),
                          decoration: InputDecoration(
                            labelText: 'Current Page',
                            labelStyle: TextStyle(
                                color: AppColors.textSecondary(context),
                                fontSize: 12),
                            filled: true,
                            fillColor: AppColors.elevatedSurface(context),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: totalController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(
                              color: AppColors.textPrimary(context),
                              fontSize: 14,
                              fontWeight: FontWeight.w700),
                          decoration: InputDecoration(
                            labelText: 'Total Pages',
                            labelStyle: TextStyle(
                                color: AppColors.textSecondary(context),
                                fontSize: 12),
                            filled: true,
                            fillColor: AppColors.elevatedSurface(context),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.elevatedSurface(context),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$parsedPage / $parsedTotal pages',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                            Text(
                              '$previewPct%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.adaptive(
                                  context,
                                  dark: _pippinEmerald,
                                  light: const Color(0xFF047857),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (parsedPage / parsedTotal).clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor: AppColors.trackSurface(context),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              _pippinEmerald,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('Cancel',
                    style: TextStyle(color: AppColors.textSecondary(context))),
              ),
              ElevatedButton(
                onPressed: () async {
                  final provider =
                      Provider.of<ReadingProvider>(context, listen: false);
                  final newTotal =
                      (int.tryParse(totalController.text.trim()) ??
                              book.totalPages)
                          .clamp(1, 99999);
                  final newPage =
                      (int.tryParse(pageController.text.trim()) ??
                              book.safeCurrentPage)
                          .clamp(0, newTotal);
                  final wasFinished = book.isCompleted;

                  Navigator.of(ctx).pop();

                  if (newTotal != book.totalPages) {
                    await provider.updateBook(
                      book.copyWith(totalPages: newTotal),
                    );
                  }
                  final justFinished =
                      await provider.updatePageProgress(book.id, newPage);
                  final updated = provider.findById(book.id);
                  if (!wasFinished &&
                      justFinished &&
                      updated != null &&
                      context.mounted) {
                    showReadingCelebrationDialog(context, updated);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _pippinEmerald,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Save Page',
                  style: TextStyle(
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

Future<void> showReadingCelebrationDialog(
  BuildContext context,
  ReadingItem book,
) async {
  int rating = book.rating ?? 5;
  final notesController = TextEditingController(text: book.notes ?? '');

  await showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.sheetSurface(context),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 6),
                  const Text('🦜🎉', style: TextStyle(fontSize: 42)),
                  const SizedBox(height: 10),
                  Text(
                    'Book Finished!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pippin stamped "${book.title}" as 100% complete (${book.totalPages} pages)!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'YOUR RATING',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary(context),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int star = 1; star <= 5; star++)
                        IconButton(
                          icon: Icon(
                            star <= rating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: star <= rating
                                ? _pippinGold
                                : AppColors.textMuted(context),
                            size: 28,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          constraints: const BoxConstraints(),
                          onPressed: () =>
                              setDialogState(() => rating = star),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontSize: 12,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Key takeaway or favorite quote (optional)...',
                      hintStyle: TextStyle(
                          color: AppColors.textMuted(context), fontSize: 12),
                      filled: true,
                      fillColor: AppColors.elevatedSurface(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('Close',
                    style: TextStyle(color: AppColors.textSecondary(context))),
              ),
              ElevatedButton(
                onPressed: () async {
                  await Provider.of<ReadingProvider>(context, listen: false)
                      .updateNotesAndRating(
                    book.id,
                    rating: rating,
                    notes: notesController.text.trim(),
                  );
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _pippinEmerald,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Save Takeaway',
                  style: TextStyle(
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

