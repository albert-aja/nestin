import 'alarm_category.dart';
import '../../domain/notes/markdown_checklist_helper.dart';

class NoteItem {
  final String id;
  final String title;
  final String content;
  final AlarmCategory category;
  final List<String> tags;
  final bool isPinned;
  final bool isArchived;
  final int? colorValue;
  final String? linkedReminderId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NoteItem({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    this.tags = const [],
    this.isPinned = false,
    this.isArchived = false,
    this.colorValue,
    this.linkedReminderId,
    required this.createdAt,
    required this.updatedAt,
  });

  ChecklistSummary get checklistSummary =>
      MarkdownChecklistHelper.summarize(content);

  NoteItem copyWith({
    String? id,
    String? title,
    String? content,
    AlarmCategory? category,
    List<String>? tags,
    bool? isPinned,
    bool? isArchived,
    int? colorValue,
    bool? clearColorValue,
    String? linkedReminderId,
    bool? clearLinkedReminderId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NoteItem(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      colorValue: clearColorValue == true ? null : (colorValue ?? this.colorValue),
      linkedReminderId: clearLinkedReminderId == true ? null : (linkedReminderId ?? this.linkedReminderId),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'category': category.toJson(),
      'tags': tags,
      'isPinned': isPinned,
      'isArchived': isArchived,
      'colorValue': colorValue,
      'linkedReminderId': linkedReminderId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory NoteItem.fromJson(Map<String, dynamic> json) {
    final rawTags = (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    return NoteItem(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      category: AlarmCategory.fromJson(json['category']),
      tags: rawTags,
      isPinned: json['isPinned'] as bool? ?? false,
      isArchived: json['isArchived'] as bool? ?? false,
      colorValue: json['colorValue'] as int?,
      linkedReminderId: json['linkedReminderId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }
}

