class MemoryItem {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final List<String> tags;
  final bool isMilestone;
  final String? photoUrl;
  final DateTime createdAt;

  const MemoryItem({
    required this.id,
    required this.title,
    this.description = '',
    required this.date,
    this.tags = const [],
    this.isMilestone = false,
    this.photoUrl,
    required this.createdAt,
  });

  MemoryItem copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? date,
    List<String>? tags,
    bool? isMilestone,
    String? photoUrl,
    DateTime? createdAt,
  }) {
    return MemoryItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      tags: tags ?? this.tags,
      isMilestone: isMilestone ?? this.isMilestone,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date.toIso8601String(),
      'tags': tags,
      'isMilestone': isMilestone,
      'photoUrl': photoUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory MemoryItem.fromJson(Map<String, dynamic> json) {
    final rawTags = (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    return MemoryItem(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Memory',
      description: json['description'] as String? ?? '',
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : DateTime.now(),
      tags: rawTags,
      isMilestone: json['isMilestone'] as bool? ?? false,
      photoUrl: json['photoUrl'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }
}

