import 'package:flutter/material.dart';

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

