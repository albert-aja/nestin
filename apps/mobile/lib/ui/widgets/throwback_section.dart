import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/journal_entry.dart';
import '../../data/models/throwback_item.dart';
import '../../providers/journal_provider.dart';
import '../../providers/settings_provider.dart';
import 'security_pin_gate_sheet.dart';

class ThrowbackSection extends StatefulWidget {
  const ThrowbackSection({super.key});

  @override
  State<ThrowbackSection> createState() => _ThrowbackSectionState();
}

class _ThrowbackSectionState extends State<ThrowbackSection> {
  int _currentIndex = 0;

  void _showThrowbackDetail(BuildContext context, ThrowbackItem item) {
    showDialog(
      context: context,
      builder: (ctx) {
        final accent = AppColors.adaptive(
          ctx,
          dark: AppColors.accent,
          light: const Color(0xFFB45309),
        );
        final loveAccent = AppColors.adaptive(
          ctx,
          dark: AppColors.primaryLight,
          light: AppColors.primary,
        );
        return AlertDialog(
          backgroundColor: AppColors.adaptive(
            ctx,
            dark: const Color(0xFF16171D),
            light: Colors.white,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          actionsPadding: const EdgeInsets.all(16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  item.isMemory ? Icons.auto_awesome_rounded : Icons.book_outlined,
                  color: accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.timeAgoLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                    Text(
                      DateFormat('EEEE, MMMM d, yyyy').format(item.date),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary(ctx),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.title.isNotEmpty) ...[
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: AppColors.textPrimary(ctx),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  item.content,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.adaptive(
                      ctx,
                      dark: const Color(0xFFD1D5DB),
                      light: const Color(0xFF374151),
                    ),
                    height: 1.5,
                  ),
                ),
                if (item.gratitudeNote != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.favorite_rounded,
                          size: 16,
                          color: loveAccent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Grateful: ${item.gratitudeNote!}',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: loveAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final journalProvider = Provider.of<JournalProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);

    if (!settings.showThrowbacks) {
      return const SizedBox.shrink();
    }

    final throwbacks = journalProvider.getThrowbackMemories();
    if (throwbacks.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_currentIndex >= throwbacks.length) {
      _currentIndex = 0;
    }

    final current = throwbacks[_currentIndex];
    final matchingEntry = journalProvider.findEntryById(current.id);
    final isLocked = matchingEntry != null
        ? settings.isEntryLocked(matchingEntry)
        : (current.isPrivate && !settings.isDiaryUnlocked);

    final isDark = AppColors.isDark(context);
    final accent = AppColors.adaptive(
      context,
      dark: AppColors.accent,
      light: const Color(0xFFB45309),
    );
    final loveAccent = AppColors.adaptive(
      context,
      dark: AppColors.primaryLight,
      light: AppColors.primary,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [
                  Color(0xFF261D15),
                  Color(0xFF1E1B18),
                  Color(0xFF16171D),
                ]
              : const [
                  Color(0xFFFFF7ED),
                  Color(0xFFFFFBF5),
                  Color(0xFFFFFFFF),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: isDark ? 0.35 : 0.45),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar: Throwback Header + Counter
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.history_toggle_off_rounded,
                    color: accent,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'On This Day',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: accent,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.3)
                        : AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    current.timeAgoLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.adaptive(
                        context,
                        dark: const Color(0xFFE5E7EB),
                        light: const Color(0xFF92400E),
                      ),
                    ),
                  ),
                ),
                if (throwbacks.length > 1) ...[
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _currentIndex = (_currentIndex + 1) % throwbacks.length;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: accent,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Content or Locked State
            if (isLocked) ...[
              InkWell(
                onTap: () async {
                  if (matchingEntry != null) {
                    await SecurityPinGateSheet.verifyEntryOrPrompt(
                      context,
                      matchingEntry,
                      title: 'Unlock Throwback Memory',
                    );
                  } else {
                    await SecurityPinGateSheet.verifyOrPrompt(
                      context,
                      title: 'Unlock Throwback Memory',
                      subtitle: 'Enter PIN to view private throwback reflection',
                    );
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.25)
                        : AppColors.elevatedSurface(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border(context)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        matchingEntry?.usesCustomPassword == true
                            ? Icons.password_rounded
                            : Icons.lock_rounded,
                        color: accent,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        current.hasCustomLock
                            ? 'Custom Locked Reflection — Tap to Unlock'
                            : 'Private Reflection — Tap to Unlock',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              InkWell(
                onTap: () => _showThrowbackDetail(context, current),
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (current.mood != null) ...[
                          Text(current.mood!.emoji, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            current.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          DateFormat('MMM d, yyyy').format(current.date),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      current.content,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.adaptive(
                          context,
                          dark: const Color(0xFFD1D5DB),
                          light: const Color(0xFF374151),
                        ),
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (current.gratitudeNote != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.favorite_rounded,
                            size: 12,
                            color: loveAccent,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Grateful: ${current.gratitudeNote!}',
                              style: TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: loveAccent,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

