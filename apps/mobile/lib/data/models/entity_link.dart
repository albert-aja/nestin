import 'package:uuid/uuid.dart';

/// Supported cross-module entity types across all six Nestin bird families.
enum LinkEntityType {
  calendarEvent,
  task,
  note,
  reminder,
  journalEntry,
  memory,
  hobby,
  readingBook,
  medication,
  beforeYouGoPreset,
  automationRule,
}

extension LinkEntityTypeExt on LinkEntityType {
  String get label {
    switch (this) {
      case LinkEntityType.calendarEvent:
        return 'Calendar Event';
      case LinkEntityType.task:
        return 'Task';
      case LinkEntityType.note:
        return 'Note';
      case LinkEntityType.reminder:
        return 'Reminder';
      case LinkEntityType.journalEntry:
        return 'Journal Entry';
      case LinkEntityType.memory:
        return 'Memory';
      case LinkEntityType.hobby:
        return 'Hobby';
      case LinkEntityType.readingBook:
        return 'Reading Book';
      case LinkEntityType.medication:
        return 'Medication';
      case LinkEntityType.beforeYouGoPreset:
        return 'Before You Go Checklist';
      case LinkEntityType.automationRule:
        return 'Automation Rule';
    }
  }

  String get familyLabel {
    switch (this) {
      case LinkEntityType.calendarEvent:
      case LinkEntityType.task:
      case LinkEntityType.reminder:
        return 'Roo';
      case LinkEntityType.journalEntry:
      case LinkEntityType.memory:
        return 'Echo';
      case LinkEntityType.medication:
        return 'Seren';
      case LinkEntityType.hobby:
      case LinkEntityType.readingBook:
        return 'Pippin';
      case LinkEntityType.note:
        return 'Twill';
      case LinkEntityType.beforeYouGoPreset:
      case LinkEntityType.automationRule:
        return 'Scout';
    }
  }
}

class LinkedEntityRef {
  final String linkId;
  final LinkEntityType entityType;
  final String entityId;
  final String title;
  final String relationship;

  const LinkedEntityRef({
    required this.linkId,
    required this.entityType,
    required this.entityId,
    required this.title,
    required this.relationship,
  });
}

/// First-class bidirectional link between two Nestin entities without data
/// duplication.
class EntityLink {
  final String id;
  final LinkEntityType sourceType;
  final String sourceId;
  final String sourceTitle;
  final LinkEntityType targetType;
  final String targetId;
  final String targetTitle;
  final String relationship;
  final DateTime createdAt;

  EntityLink({
    String? id,
    required this.sourceType,
    required this.sourceId,
    required this.sourceTitle,
    required this.targetType,
    required this.targetId,
    required this.targetTitle,
    this.relationship = 'related',
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  bool connects(LinkEntityType type, String entityId) {
    return (sourceType == type && sourceId == entityId) ||
        (targetType == type && targetId == entityId);
  }

  bool matchesPair(
    LinkEntityType aType,
    String aId,
    LinkEntityType bType,
    String bId,
  ) {
    final forward = sourceType == aType &&
        sourceId == aId &&
        targetType == bType &&
        targetId == bId;
    final reverse = sourceType == bType &&
        sourceId == bId &&
        targetType == aType &&
        targetId == aId;
    return forward || reverse;
  }

  LinkedEntityRef? otherSideFor(LinkEntityType type, String entityId) {
    if (sourceType == type && sourceId == entityId) {
      return LinkedEntityRef(
        linkId: id,
        entityType: targetType,
        entityId: targetId,
        title: targetTitle,
        relationship: relationship,
      );
    }
    if (targetType == type && targetId == entityId) {
      return LinkedEntityRef(
        linkId: id,
        entityType: sourceType,
        entityId: sourceId,
        title: sourceTitle,
        relationship: relationship,
      );
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sourceType': sourceType.name,
        'sourceId': sourceId,
        'sourceTitle': sourceTitle,
        'targetType': targetType.name,
        'targetId': targetId,
        'targetTitle': targetTitle,
        'relationship': relationship,
        'createdAt': createdAt.toIso8601String(),
      };

  factory EntityLink.fromJson(Map<String, dynamic> json) {
    return EntityLink(
      id: json['id'] as String?,
      sourceType: LinkEntityType.values.firstWhere(
        (e) => e.name == json['sourceType'],
        orElse: () => LinkEntityType.note,
      ),
      sourceId: json['sourceId'] as String? ?? '',
      sourceTitle: json['sourceTitle'] as String? ?? '',
      targetType: LinkEntityType.values.firstWhere(
        (e) => e.name == json['targetType'],
        orElse: () => LinkEntityType.task,
      ),
      targetId: json['targetId'] as String? ?? '',
      targetTitle: json['targetTitle'] as String? ?? '',
      relationship: json['relationship'] as String? ?? 'related',
      createdAt: json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now())
          : DateTime.now(),
    );
  }
}
