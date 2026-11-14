import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/notes/markdown_checklist_helper.dart';

/// Lightweight, high-performance native Flutter Markdown renderer
/// for Nestin notes, live preview, and note cards.
class MarkdownContentView extends StatelessWidget {
  final String content;
  final bool isCompact;
  final int? maxLines;
  final TextStyle? baseStyle;
  final TextOverflow overflow;

  /// Optional callback invoked with the zero-based markdown line index when a
  /// user taps a checklist checkbox (`- [ ]` / `- [x]`) directly in the view.
  final ValueChanged<int>? onChecklistToggle;

  const MarkdownContentView({
    super.key,
    required this.content,
    this.isCompact = false,
    this.maxLines,
    this.baseStyle,
    this.overflow = TextOverflow.ellipsis,
    this.onChecklistToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (content.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final defaultBaseStyle = baseStyle ??
        TextStyle(
          fontSize: 13,
          color: AppColors.adaptive(
            context,
            dark: const Color(0xFFD1D5DB),
            light: const Color(0xFF374151),
          ),
          height: 1.45,
        );

    if (isCompact) {
      return _buildCompactRichText(context, defaultBaseStyle);
    } else {
      return _buildFullBlocks(context, defaultBaseStyle);
    }
  }

  static ({int level, String text})? _parseHeader(String trimmed) {
    if (trimmed.startsWith('#### ')) {
      return (level: 4, text: trimmed.substring(5));
    }
    if (trimmed.startsWith('### ')) {
      return (level: 3, text: trimmed.substring(4));
    }
    if (trimmed.startsWith('## ')) {
      return (level: 2, text: trimmed.substring(3));
    }
    if (trimmed.startsWith('# ')) {
      return (level: 1, text: trimmed.substring(2));
    }
    return null;
  }

  Widget _buildChecklistIcon(
    BuildContext context,
    ChecklistLineMatch item, {
    EdgeInsetsGeometry padding = const EdgeInsets.only(right: 6, top: 2, bottom: 2),
  }) {
    final checkedColor = AppColors.adaptive(
      context,
      dark: const Color(0xFF10B981),
      light: const Color(0xFF047857),
    );
    final icon = Icon(
      item.isChecked
          ? Icons.check_box_rounded
          : Icons.check_box_outline_blank_rounded,
      size: 16,
      color: item.isChecked ? checkedColor : AppColors.textSecondary(context),
    );

    if (onChecklistToggle == null) {
      return Padding(padding: padding, child: icon);
    }

    return Semantics(
      button: true,
      checked: item.isChecked,
      label: item.text.isEmpty
          ? 'Toggle checklist item'
          : 'Toggle checklist item: ${item.text}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          key: ValueKey('markdown_checkbox_${item.lineIndex}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => onChecklistToggle!(item.lineIndex),
          child: Padding(padding: padding, child: icon),
        ),
      ),
    );
  }

  TextStyle _checklistTextStyle(
      BuildContext context, TextStyle defaultStyle, bool isChecked) {
    if (!isChecked) return defaultStyle;
    return defaultStyle.copyWith(
      decoration: TextDecoration.lineThrough,
      color: AppColors.textSecondary(context),
    );
  }

  // --- Compact Card Mode ---
  Widget _buildCompactRichText(BuildContext context, TextStyle defaultStyle) {
    final isDark = AppColors.isDark(context);
    final bulletAccent = AppColors.adaptive(
      context,
      dark: const Color(0xFFA78BFA),
      light: const Color(0xFF7C3AED),
    );
    final quoteBarColor = AppColors.adaptive(
      context,
      dark: const Color(0xFF8B5CF6),
      light: const Color(0xFF6D28D9),
    );
    final codeColor = AppColors.adaptive(
      context,
      dark: const Color(0xFFFBBF24),
      light: const Color(0xFF9A3412),
    );
    final spans = <InlineSpan>[];
    final lines = content.split('\n');
    bool inCodeBlock = false;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();
      final hasNextLine = i < lines.length - 1;

      if (trimmed.startsWith('```')) {
        inCodeBlock = !inCodeBlock;
        continue;
      }

      if (inCodeBlock) {
        if (trimmed.isNotEmpty) {
          spans.add(TextSpan(
            text: line.trimRight(),
            style: defaultStyle.copyWith(
              fontFamily: 'monospace',
              color: codeColor,
            ),
          ));
        }
        if (hasNextLine) spans.add(const TextSpan(text: '\n'));
        continue;
      }

      if (trimmed.isEmpty) {
        if (hasNextLine) {
          spans.add(const TextSpan(text: '\n'));
        }
        continue;
      }

      final header = _parseHeader(trimmed);
      if (header != null) {
        final sizeDelta = 5 - header.level;
        spans.add(TextSpan(
          text: header.text,
          style: defaultStyle.copyWith(
            fontWeight: header.level == 1
                ? FontWeight.w900
                : (header.level == 2 ? FontWeight.w800 : FontWeight.w700),
            fontSize: (defaultStyle.fontSize ?? 13) + sizeDelta,
            color: AppColors.textPrimary(context),
          ),
        ));
        if (hasNextLine) spans.add(const TextSpan(text: '\n'));
        continue;
      }

      final checklist = MarkdownChecklistHelper.parseLine(line, lineIndex: i);
      if (checklist != null) {
        if (checklist.indent.isNotEmpty) {
          spans.add(TextSpan(text: checklist.indent, style: defaultStyle));
        }
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _buildChecklistIcon(context, checklist),
        ));
        spans.addAll(parseInlineMarkdown(
          checklist.text,
          _checklistTextStyle(context, defaultStyle, checklist.isChecked),
          isDark: isDark,
        ));
        if (hasNextLine) spans.add(const TextSpan(text: '\n'));
        continue;
      }

      if (trimmed.startsWith('- ') ||
          trimmed.startsWith('* ') ||
          trimmed.startsWith('+ ')) {
        spans.add(TextSpan(
          text: '• ',
          style: TextStyle(color: bulletAccent, fontWeight: FontWeight.bold),
        ));
        spans.addAll(parseInlineMarkdown(
          trimmed.substring(2),
          defaultStyle,
          isDark: isDark,
        ));
        if (hasNextLine) spans.add(const TextSpan(text: '\n'));
      } else if (RegExp(r'^\d+\.\s+').hasMatch(trimmed)) {
        final match = RegExp(r'^(\d+\.)\s+(.*)').firstMatch(trimmed);
        if (match != null) {
          spans.add(TextSpan(
            text: '${match.group(1)} ',
            style: TextStyle(color: bulletAccent, fontWeight: FontWeight.bold),
          ));
          spans.addAll(parseInlineMarkdown(
            match.group(2) ?? '',
            defaultStyle,
            isDark: isDark,
          ));
          if (hasNextLine) spans.add(const TextSpan(text: '\n'));
        }
      } else if (trimmed.startsWith('> ')) {
        spans.add(TextSpan(
          text: '▎ ',
          style: defaultStyle.copyWith(
              color: quoteBarColor, fontWeight: FontWeight.bold),
        ));
        spans.addAll(parseInlineMarkdown(
          trimmed.substring(2),
          defaultStyle.copyWith(
              fontStyle: FontStyle.italic,
              color: AppColors.textSecondary(context)),
          isDark: isDark,
        ));
        if (hasNextLine) spans.add(const TextSpan(text: '\n'));
      } else {
        spans.addAll(parseInlineMarkdown(trimmed, defaultStyle, isDark: isDark));
        if (hasNextLine) spans.add(const TextSpan(text: '\n'));
      }
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: maxLines ?? 4,
      overflow: overflow,
    );
  }

  // --- Full / Live Preview Mode ---
  Widget _buildFullBlocks(BuildContext context, TextStyle defaultStyle) {
    final isDark = AppColors.isDark(context);
    final bulletAccent = AppColors.adaptive(
      context,
      dark: const Color(0xFFA78BFA),
      light: const Color(0xFF7C3AED),
    );
    final quoteBarColor = AppColors.adaptive(
      context,
      dark: const Color(0xFF8B5CF6),
      light: const Color(0xFF6D28D9),
    );
    final widgets = <Widget>[];
    final lines = content.split('\n');

    bool inCodeBlock = false;
    final codeBlockBuffer = StringBuffer();

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      // Code Block Detection
      if (trimmed.startsWith('```')) {
        if (inCodeBlock) {
          // Close code block
          widgets.add(_buildCodeBlockWidget(context, codeBlockBuffer.toString()));
          codeBlockBuffer.clear();
          inCodeBlock = false;
        } else {
          // Open code block
          inCodeBlock = true;
          codeBlockBuffer.clear();
        }
        continue;
      }

      if (inCodeBlock) {
        codeBlockBuffer.writeln(line);
        continue;
      }

      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      final header = _parseHeader(trimmed);
      if (header != null) {
        final (fontSize, fontWeight, color, topPad, bottomPad) =
            switch (header.level) {
          1 => (19.0, FontWeight.w900, AppColors.textPrimary(context), 10.0, 4.0),
          2 => (16.0, FontWeight.w800, AppColors.textPrimary(context), 8.0, 4.0),
          3 => (
              14.0,
              FontWeight.w700,
              AppColors.adaptive(
                context,
                dark: const Color(0xFFF3F4F6),
                light: const Color(0xFF1F2937),
              ),
              6.0,
              3.0,
            ),
          _ => (
              13.0,
              FontWeight.w700,
              AppColors.adaptive(
                context,
                dark: const Color(0xFFE5E7EB),
                light: const Color(0xFF374151),
              ),
              4.0,
              2.0,
            ),
        };
        widgets.add(Padding(
          padding: EdgeInsets.only(top: topPad, bottom: bottomPad),
          child: Text.rich(
            TextSpan(
              children: parseInlineMarkdown(
                header.text,
                defaultStyle.copyWith(
                  fontSize: fontSize,
                  fontWeight: fontWeight,
                  color: color,
                ),
                isDark: isDark,
              ),
            ),
          ),
        ));
        continue;
      }

      if (trimmed == '---' || trimmed == '***') {
        widgets.add(Divider(color: AppColors.border(context), height: 16));
        continue;
      }

      final checklist = MarkdownChecklistHelper.parseLine(line, lineIndex: i);
      if (checklist != null) {
        final leftIndent = (checklist.indent.length * 6.0).clamp(0.0, 24.0);
        widgets.add(Padding(
          padding: EdgeInsets.only(left: leftIndent, top: 2.5, bottom: 2.5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildChecklistIcon(
                context,
                checklist,
                padding: const EdgeInsets.only(right: 8, top: 2, bottom: 2),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text.rich(
                    TextSpan(
                      children: parseInlineMarkdown(
                        checklist.text,
                        _checklistTextStyle(
                            context, defaultStyle, checklist.isChecked),
                        isDark: isDark,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ));
        continue;
      }

      if (trimmed.startsWith('- ') ||
          trimmed.startsWith('* ') ||
          trimmed.startsWith('+ ')) {
        // Bullet List Item
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Icon(Icons.circle, size: 6, color: bulletAccent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                      children: parseInlineMarkdown(
                          trimmed.substring(2), defaultStyle,
                          isDark: isDark)),
                ),
              ),
            ],
          ),
        ));
      } else if (RegExp(r'^\d+\.\s+').hasMatch(trimmed)) {
        // Numbered List Item
        final match = RegExp(r'^(\d+\.)\s+(.*)').firstMatch(trimmed);
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${match?.group(1)} ',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: bulletAccent,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text.rich(
                  TextSpan(
                      children: parseInlineMarkdown(
                          match?.group(2) ?? '', defaultStyle,
                          isDark: isDark)),
                ),
              ),
            ],
          ),
        ));
      } else if (trimmed.startsWith('> ')) {
        // Blockquote
        widgets.add(Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.only(left: 10, top: 4, bottom: 4, right: 6),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: quoteBarColor, width: 3)),
            color: AppColors.adaptive(
              context,
              dark: const Color(0xFF1B1D26),
              light: const Color(0xFFF3F0FF),
            ),
          ),
          child: Text.rich(
            TextSpan(
                children: parseInlineMarkdown(
              trimmed.substring(2),
              defaultStyle.copyWith(
                fontStyle: FontStyle.italic,
                color: AppColors.adaptive(
                  context,
                  dark: const Color(0xFFB0B4C0),
                  light: const Color(0xFF4B5563),
                ),
              ),
              isDark: isDark,
            )),
          ),
        ));
      } else {
        // Normal Paragraph
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.5),
          child: Text.rich(
            TextSpan(
                children: parseInlineMarkdown(trimmed, defaultStyle,
                    isDark: isDark)),
          ),
        ));
      }
    }

    if (inCodeBlock && codeBlockBuffer.isNotEmpty) {
      widgets.add(_buildCodeBlockWidget(context, codeBlockBuffer.toString()));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }

  Widget _buildCodeBlockWidget(BuildContext context, String code) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.adaptive(
          context,
          dark: const Color(0xFF12131A),
          light: const Color(0xFFF1F5F9),
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Text(
          code.trimRight(),
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: AppColors.adaptive(
              context,
              dark: const Color(0xFFFBBF24),
              light: const Color(0xFF9A3412),
            ),
            height: 1.4,
          ),
        ),
      ),
    );
  }

  /// Parses inline markdown syntax:
  /// `code`, ***bold italic***, **bold**, __bold__, *italic*, _italic_, ~~strike~~
  static List<InlineSpan> parseInlineMarkdown(
    String text,
    TextStyle baseStyle, {
    bool isDark = true,
  }) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(
      r'(`[^`]+`|\*\*\*[^*]+\*\*\*|\*\*[^*]+\*\*|__[^_]+__|\*[^*]+\*|_[^_]+_|~~[^~]+~~)',
    );
    final strongColor = isDark ? Colors.white : AppColors.lightTextPrimary;
    final strikeColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    int lastIndex = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: baseStyle,
        ));
      }

      final matchedText = match.group(0)!;

      if (matchedText.startsWith('`') && matchedText.endsWith('`')) {
        // Inline code span
        final codeContent = matchedText.substring(1, matchedText.length - 1);
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              color:
                  isDark ? const Color(0xFF242733) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF35394A) : const Color(0xFFCBD5E1),
                width: 0.8,
              ),
            ),
            child: Text(
              codeContent,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11.5,
                color:
                    isDark ? const Color(0xFFFBBF24) : const Color(0xFF9A3412),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ));
      } else if (matchedText.startsWith('***') && matchedText.endsWith('***')) {
        // Bold Italic
        final inner = matchedText.substring(3, matchedText.length - 3);
        spans.add(TextSpan(
          text: inner,
          style: baseStyle.copyWith(
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
            color: strongColor,
          ),
        ));
      } else if ((matchedText.startsWith('**') && matchedText.endsWith('**')) ||
          (matchedText.startsWith('__') && matchedText.endsWith('__'))) {
        // Bold
        final inner = matchedText.substring(2, matchedText.length - 2);
        spans.add(TextSpan(
          text: inner,
          style: baseStyle.copyWith(
            fontWeight: FontWeight.w700,
            color: strongColor,
          ),
        ));
      } else if ((matchedText.startsWith('*') && matchedText.endsWith('*')) ||
          (matchedText.startsWith('_') && matchedText.endsWith('_'))) {
        // Italic
        final inner = matchedText.substring(1, matchedText.length - 1);
        spans.add(TextSpan(
          text: inner,
          style: baseStyle.copyWith(
            fontStyle: FontStyle.italic,
          ),
        ));
      } else if (matchedText.startsWith('~~') && matchedText.endsWith('~~')) {
        // Strikethrough
        final inner = matchedText.substring(2, matchedText.length - 2);
        spans.add(TextSpan(
          text: inner,
          style: baseStyle.copyWith(
            decoration: TextDecoration.lineThrough,
            color: strikeColor,
          ),
        ));
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: baseStyle,
      ));
    }

    return spans;
  }
}

