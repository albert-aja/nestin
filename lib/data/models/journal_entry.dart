enum JournalMood {
  great,
  good,
  neutral,
  low,
  tough,
}

extension JournalMoodExt on JournalMood {
  String get emoji {
    switch (this) {
      case JournalMood.great:
        return '😄';
      case JournalMood.good:
        return '🙂';
      case JournalMood.neutral:
        return '😐';
      case JournalMood.low:
        return '😔';
      case JournalMood.tough:
        return '😫';
    }
  }

  String get label {
    switch (this) {
      case JournalMood.great:
        return 'Great';
      case JournalMood.good:
        return 'Good';
      case JournalMood.neutral:
        return 'Neutral';
      case JournalMood.low:
        return 'Low Energy';
      case JournalMood.tough:
        return 'Tough Day';
    }
  }
}

class JournalEntry {
  final String id;
  final String title;
  final String content;
  final DateTime date;
  final JournalMood mood;
  final List<String> tags;
  final String? gratitudeNote;
  final bool isPrivate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const JournalEntry({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
    this.mood = JournalMood.good,
    this.tags = const [],
    this.gratitudeNote,
    this.isPrivate = false,
    required this.createdAt,
    required this.updatedAt,
  });

  JournalEntry copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? date,
    JournalMood? mood,
    List<String>? tags,
    String? gratitudeNote,
    bool? clearGratitude,
    bool? isPrivate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      date: date ?? this.date,
      mood: mood ?? this.mood,
      tags: tags ?? this.tags,
      gratitudeNote: clearGratitude == true ? null : (gratitudeNote ?? this.gratitudeNote),
      isPrivate: isPrivate ?? this.isPrivate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'date': date.toIso8601String(),
      'mood': mood.name,
      'tags': tags,
      'gratitudeNote': gratitudeNote,
      'isPrivate': isPrivate,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    final moodName = json['mood'] as String? ?? 'good';
    final moodVal = JournalMood.values.firstWhere(
      (m) => m.name == moodName,
      orElse: () => JournalMood.good,
    );
    final rawTags = (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

    return JournalEntry(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : DateTime.now(),
      mood: moodVal,
      tags: rawTags,
      gratitudeNote: json['gratitudeNote'] as String?,
      isPrivate: json['isPrivate'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }
}

