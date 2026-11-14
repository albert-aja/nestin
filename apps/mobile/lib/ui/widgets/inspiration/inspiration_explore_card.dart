import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../providers/inspiration_provider.dart';
import '../../screens/inspiration/inspiration_screen.dart';
import '../../screens/inspiration/quote_card_studio_screen.dart';

class InspirationExploreCard extends StatelessWidget {
  const InspirationExploreCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Consumer<InspirationProvider>(
      builder: (context, provider, _) {
        final quote = provider.featuredQuote;
        final isFav = provider.isFavorite(quote.id);

        return InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const InspirationScreen()),
          ),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: AppColors.isDark(context)
                    ? const [Color(0xFF231926), Color(0xFF1A1B24)]
                    : const [Color(0xFFFFF4EE), Color(0xFFFFFFFF)],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.35),
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
                        color: AppColors.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.auto_awesome_rounded,
                            size: 13,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            l10n.pick('DAILY INSPIRATION', 'INSPIRASI HARIAN'),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: l10n.pick('Save Favorite', 'Simpan Favorit'),
                      icon: Icon(
                        isFav
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        color: isFav
                            ? AppColors.accent
                            : AppColors.textSecondary(context),
                        size: 20,
                      ),
                      onPressed: () => provider.toggleFavorite(quote),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: l10n.pick('Create Quote Card', 'Buat Kartu Kutipan'),
                      icon: const Icon(
                        Icons.palette_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => QuoteCardStudioScreen(
                            quoteText: quote.quoteText,
                            authorName: quote.author,
                            initialMascotDomain: quote.mascotDomain,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '“${quote.quoteText}”',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.38,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '— ${quote.author}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ),
                    Text(
                      l10n.pick('Open Library', 'Buka Pustaka'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: AppColors.primary,
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
