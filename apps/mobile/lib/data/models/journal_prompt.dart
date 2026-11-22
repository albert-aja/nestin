import 'package:material_ui/material_ui.dart';

class JournalPrompt {
  final String id;
  final String category;
  final String prompt;
  final IconData icon;
  final Color color;

  const JournalPrompt({
    required this.id,
    required this.category,
    required this.prompt,
    required this.icon,
    required this.color,
  });

  static const List<JournalPrompt> defaultPrompts = [
    JournalPrompt(
      id: 'p1',
      category: 'Morning Intention',
      prompt: 'What was the highlight of your morning or your main intention today?',
      icon: Icons.wb_sunny_rounded,
      color: Color(0xFFF59E0B),
    ),
    JournalPrompt(
      id: 'p2',
      category: 'Daily Gratitude',
      prompt: 'Who made a positive difference in your day, and how did it feel?',
      icon: Icons.favorite_rounded,
      color: Color(0xFFEF4444),
    ),
    JournalPrompt(
      id: 'p3',
      category: 'Small Comforts',
      prompt: 'What is a small everyday comfort you appreciated or often take for granted?',
      icon: Icons.coffee_rounded,
      color: Color(0xFF10B981),
    ),
    JournalPrompt(
      id: 'p4',
      category: 'Growth & Resilience',
      prompt: 'What challenge did you navigate with patience or wisdom today?',
      icon: Icons.psychology_rounded,
      color: Color(0xFF3B82F6),
    ),
    JournalPrompt(
      id: 'p5',
      category: 'Mindful Moment',
      prompt: 'What is one thing that brought your mind peace or made you smile today?',
      icon: Icons.spa_rounded,
      color: Color(0xFF8B5CF6),
    ),
    JournalPrompt(
      id: 'p6',
      category: 'Evening Unwind',
      prompt: 'What is one thing or worry you are ready to let go of tonight before sleep?',
      icon: Icons.nightlight_round,
      color: Color(0xFF6366F1),
    ),
    JournalPrompt(
      id: 'p7',
      category: 'Self Discovery',
      prompt: 'What is a valuable lesson or reminder you experienced about yourself today?',
      icon: Icons.auto_awesome_rounded,
      color: Color(0xFFEC4899),
    ),
  ];
}

/// Selectable 3-question guided evening reflection template for Echo's Diary.
class GuidedReflectionTemplate {
  final String id;
  final String titleKey;
  final String subtitleKey;
  final List<String> questionKeys;
  final String tag;
  final IconData icon;
  final Color color;

  const GuidedReflectionTemplate({
    required this.id,
    required this.titleKey,
    required this.subtitleKey,
    required this.questionKeys,
    required this.tag,
    required this.icon,
    required this.color,
  });

  static const List<GuidedReflectionTemplate> eveningTemplates = [
    GuidedReflectionTemplate(
      id: 'rose_thorn_bud',
      titleKey: 'diary_tpl_rose_title',
      subtitleKey: 'diary_tpl_rose_sub',
      questionKeys: [
        'diary_tpl_rose_q1',
        'diary_tpl_rose_q2',
        'diary_tpl_rose_q3',
      ],
      tag: 'RoseThornBud',
      icon: Icons.local_florist_rounded,
      color: Color(0xFFEC4899),
    ),
    GuidedReflectionTemplate(
      id: 'three_good_things',
      titleKey: 'diary_tpl_good_title',
      subtitleKey: 'diary_tpl_good_sub',
      questionKeys: [
        'diary_tpl_good_q1',
        'diary_tpl_good_q2',
        'diary_tpl_good_q3',
      ],
      tag: '3GoodThings',
      icon: Icons.auto_awesome_rounded,
      color: Color(0xFF10B981),
    ),
    GuidedReflectionTemplate(
      id: 'anxiety_unload',
      titleKey: 'diary_tpl_anxiety_title',
      subtitleKey: 'diary_tpl_anxiety_sub',
      questionKeys: [
        'diary_tpl_anxiety_q1',
        'diary_tpl_anxiety_q2',
        'diary_tpl_anxiety_q3',
      ],
      tag: 'AnxietyUnload',
      icon: Icons.air_rounded,
      color: Color(0xFF8B5CF6),
    ),
    GuidedReflectionTemplate(
      id: 'weekly_wins',
      titleKey: 'diary_tpl_wins_title',
      subtitleKey: 'diary_tpl_wins_sub',
      questionKeys: [
        'diary_tpl_wins_q1',
        'diary_tpl_wins_q2',
        'diary_tpl_wins_q3',
      ],
      tag: 'WeeklyWins',
      icon: Icons.emoji_events_outlined,
      color: Color(0xFFF59E0B),
    ),
  ];

  bool hasAnyAnswer(List<String> answers) =>
      answers.any((a) => a.trim().isNotEmpty);

  /// Formats answered 3-question prompts plus optional [extraNotes] into clean
  /// structured text for `JournalEntry.content`.
  String formatGuidedContent({
    required String Function(String key) tr,
    required List<String> answers,
    String extraNotes = '',
  }) {
    final buffer = StringBuffer();
    for (var i = 0; i < questionKeys.length; i++) {
      final answer = i < answers.length ? answers[i].trim() : '';
      if (answer.isEmpty) continue;
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.writeln('• ${tr(questionKeys[i])}');
      buffer.writeln('  $answer');
    }
    final extra = extraNotes.trim();
    if (extra.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.write(extra);
    }
    return buffer.toString().trim();
  }
}

