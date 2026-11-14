import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/journal_prompt.dart';
import '../../providers/settings_provider.dart';

class JournalPromptCarousel extends StatefulWidget {
  final ValueChanged<JournalPrompt> onAnswerPrompt;

  const JournalPromptCarousel({
    super.key,
    required this.onAnswerPrompt,
  });

  @override
  State<JournalPromptCarousel> createState() => _JournalPromptCarouselState();
}

class _JournalPromptCarouselState extends State<JournalPromptCarousel> {
  late final PageController _pageController;
  int _currentIndex = 0;
  final List<JournalPrompt> _prompts = JournalPrompt.defaultPrompts;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _shufflePrompt() {
    HapticFeedback.selectionClick();
    final next = (_currentIndex + 1) % _prompts.length;
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    if (!settings.showJournalPrompts) {
      return const SizedBox.shrink();
    }

    final accent = AppColors.adaptive(
      context,
      dark: AppColors.accent,
      light: const Color(0xFFB45309),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 16,
                  color: accent,
                ),
                const SizedBox(width: 6),
                Text(
                  'Daily Reflection Prompt',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.adaptive(
                      context,
                      dark: const Color(0xFFD1D5DB),
                      light: AppColors.lightTextPrimary,
                    ),
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: _shufflePrompt,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.casino_outlined,
                          size: 14,
                          color: accent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Shuffle',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Horizontal Carousel
          SizedBox(
            height: 132,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _prompts.length,
              onPageChanged: (idx) => setState(() => _currentIndex = idx),
              itemBuilder: (context, index) {
                final item = _prompts[index];
                final itemAccent = AppColors.adaptive(
                  context,
                  dark: item.color,
                  light: Color.lerp(item.color, Colors.black, 0.25) ?? item.color,
                );
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.adaptive(
                        context,
                        dark: const Color(0xFF1B1D25),
                        light: Colors.white,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: item.color.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category pill + Icon
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: item.color.withValues(
                                  alpha: AppColors.isDark(context) ? 0.18 : 0.14,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(item.icon, size: 12, color: itemAccent),
                                  const SizedBox(width: 4),
                                  Text(
                                    item.category,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: itemAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${index + 1}/${_prompts.length}',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Prompt Text
                        Expanded(
                          child: Text(
                            item.prompt,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary(context),
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // Action button
                        Align(
                          alignment: Alignment.centerRight,
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              widget.onAnswerPrompt(item);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(
                                  alpha: AppColors.isDark(context) ? 0.2 : 0.14,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.accent.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.edit_note_rounded,
                                    size: 14,
                                    color: accent,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Answer Prompt',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

