/// Parsed metadata for a single markdown task checklist line.
class ChecklistLineMatch {
  final int lineIndex;
  final String prefix;
  final String indent;
  final String marker;
  final bool isChecked;
  final String postBracketSpacing;
  final String text;
  final String crSuffix;

  const ChecklistLineMatch({
    required this.lineIndex,
    required this.prefix,
    required this.indent,
    required this.marker,
    required this.isChecked,
    required this.postBracketSpacing,
    required this.text,
    required this.crSuffix,
  });

  /// Returns the line with its checkbox state flipped (`[ ]` <-> `[x]`),
  /// preserving original indentation, bullet marker, spacing, and CRLF ending.
  String toggledLine() {
    final nextState = isChecked ? ' ' : 'x';
    return '$prefix$nextState]$postBracketSpacing$text$crSuffix';
  }
}

/// Completion statistics for checklist items contained in a markdown document.
class ChecklistSummary {
  final int completed;
  final int total;

  const ChecklistSummary({
    required this.completed,
    required this.total,
  });

  bool get hasItems => total > 0;
  bool get isAllComplete => total > 0 && completed == total;
}

/// Pure markdown task-list helper shared by note models, providers, and UI views.
class MarkdownChecklistHelper {
  MarkdownChecklistHelper._();

  // Matches `- [ ] text`, `* [x] text`, `+ [X] text`, optional leading indent,
  // or an empty checklist box like `- [ ]`. Avoids matching markdown links
  // like `- [x](url)` by requiring whitespace or end-of-line after `]`.
  static final RegExp _checklistLineRegex = RegExp(
    r'^(\s*)([-*+])(\s+\[)([ xX])\](?:([ \t]+)(.*)|([ \t]*))$',
  );

  /// Parses [line] as a markdown checklist item, returning `null` if it is not one.
  static ChecklistLineMatch? parseLine(String line, {int lineIndex = 0}) {
    final hasCr = line.endsWith('\r');
    final cleanLine = hasCr ? line.substring(0, line.length - 1) : line;
    final match = _checklistLineRegex.firstMatch(cleanLine);
    if (match == null) return null;

    final indent = match.group(1) ?? '';
    final marker = match.group(2) ?? '-';
    final bracketStart = match.group(3) ?? ' [';
    final stateChar = match.group(4) ?? ' ';
    final spacingWithText = match.group(5);
    final itemText = match.group(6) ?? '';
    final trailingSpaceOnly = match.group(7) ?? '';

    return ChecklistLineMatch(
      lineIndex: lineIndex,
      prefix: '$indent$marker$bracketStart',
      indent: indent,
      marker: marker,
      isChecked: stateChar == 'x' || stateChar == 'X',
      postBracketSpacing: spacingWithText ?? trailingSpaceOnly,
      text: itemText,
      crSuffix: hasCr ? '\r' : '',
    );
  }

  /// Toggles the checklist item at zero-based [lineIndex] in [content].
  ///
  /// Returns `null` if [lineIndex] is out of bounds, inside a fenced code block
  /// (` ``` `), or not a valid checklist line.
  static String? toggleChecklistAtLine(String content, int lineIndex) {
    if (lineIndex < 0) return null;
    final lines = content.split('\n');
    if (lineIndex >= lines.length) return null;

    bool inCodeBlock = false;
    for (int i = 0; i <= lineIndex; i++) {
      final trimmed = lines[i].trim();
      if (trimmed.startsWith('```')) {
        inCodeBlock = !inCodeBlock;
        if (i == lineIndex) return null;
      }
    }

    if (inCodeBlock) return null;

    final parsed = parseLine(lines[lineIndex], lineIndex: lineIndex);
    if (parsed == null) return null;

    lines[lineIndex] = parsed.toggledLine();
    return lines.join('\n');
  }

  /// Summarizes total and checked checklist items outside fenced code blocks.
  static ChecklistSummary summarize(String content) {
    if (content.isEmpty) {
      return const ChecklistSummary(completed: 0, total: 0);
    }

    final lines = content.split('\n');
    bool inCodeBlock = false;
    int completed = 0;
    int total = 0;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().startsWith('```')) {
        inCodeBlock = !inCodeBlock;
        continue;
      }
      if (inCodeBlock) continue;

      final parsed = parseLine(line, lineIndex: i);
      if (parsed != null) {
        total++;
        if (parsed.isChecked) completed++;
      }
    }

    return ChecklistSummary(completed: completed, total: total);
  }

  /// Returns `true` when [content] contains at least one checklist item outside code fences.
  static bool hasChecklist(String content) => summarize(content).hasItems;
}

