import 'package:flutter/material.dart';

class CollectionEntry {
  final String id;
  final String text;
  final bool isChecked;
  final String? notes;
  final String? urlLink;

  const CollectionEntry({
    required this.id,
    required this.text,
    this.isChecked = false,
    this.notes,
    this.urlLink,
  });

  CollectionEntry copyWith({
    String? id,
    String? text,
    bool? isChecked,
    String? notes,
    String? urlLink,
  }) {
    return CollectionEntry(
      id: id ?? this.id,
      text: text ?? this.text,
      isChecked: isChecked ?? this.isChecked,
      notes: notes ?? this.notes,
      urlLink: urlLink ?? this.urlLink,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'isChecked': isChecked,
        'notes': notes,
        'urlLink': urlLink,
      };

  factory CollectionEntry.fromJson(Map<String, dynamic> json) =>
      CollectionEntry(
        id: json['id'] as String? ?? '',
        text: json['text'] as String? ?? '',
        isChecked: json['isChecked'] as bool? ?? false,
        notes: json['notes'] as String?,
        urlLink: json['urlLink'] as String?,
      );
}

class CollectionItem {
  final String id;
  final String title;
  final String description;
  final int iconCodePoint;
  final int colorValue;
  final List<CollectionEntry> entries;
  final DateTime createdAt;

  const CollectionItem({
    required this.id,
    required this.title,
    this.description = '',
    this.iconCodePoint = 0xe148, // Icons.list_rounded
    this.colorValue = 0xFF3A86FF,
    this.entries = const [],
    required this.createdAt,
  });

  int get totalCount => entries.length;
  int get checkedCount => entries.where((e) => e.isChecked).length;
  double get progress => totalCount == 0 ? 0.0 : checkedCount / totalCount;

  IconData get displayIcon {
    switch (iconCodePoint) {
      case 0xe59c:
        return Icons.shopping_cart_rounded;
      case 0xe3ab:
        return Icons.location_on_rounded;
      case 0xe148:
        return Icons.list_rounded;
      case 0xe52f:
        return Icons.restaurant_rounded;
      case 0xe163:
        return Icons.bookmark_rounded;
      case 0xe3e3:
        return Icons.movie_rounded;
      case 0xe473:
        return Icons.flight_takeoff_rounded;
      default:
        return Icons.format_list_bulleted_rounded;
    }
  }

  CollectionItem copyWith({
    String? id,
    String? title,
    String? description,
    int? iconCodePoint,
    int? colorValue,
    List<CollectionEntry>? entries,
    DateTime? createdAt,
  }) {
    return CollectionItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
      entries: entries ?? this.entries,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'iconCodePoint': iconCodePoint,
      'colorValue': colorValue,
      'entries': entries.map((e) => e.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CollectionItem.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'] as List<dynamic>? ?? [];
    final list = rawEntries
        .map((e) => CollectionEntry.fromJson(e as Map<String, dynamic>))
        .toList();

    return CollectionItem(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'List',
      description: json['description'] as String? ?? '',
      iconCodePoint: json['iconCodePoint'] as int? ?? 0xe148,
      colorValue: json['colorValue'] as int? ?? 0xFF3A86FF,
      entries: list,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }
}
