enum ReadingStatus {
  wantToRead,
  currentlyReading,
  finished,
}

extension ReadingStatusExt on ReadingStatus {
  String get label {
    switch (this) {
      case ReadingStatus.wantToRead:
        return 'Want to Read';
      case ReadingStatus.currentlyReading:
        return 'Reading';
      case ReadingStatus.finished:
        return 'Finished';
    }
  }

  String get emoji {
    switch (this) {
      case ReadingStatus.wantToRead:
        return '🔖';
      case ReadingStatus.currentlyReading:
        return '📖';
      case ReadingStatus.finished:
        return '✅';
    }
  }

  int get colorValue {
    switch (this) {
      case ReadingStatus.wantToRead:
        return 0xFF3B82F6;
      case ReadingStatus.currentlyReading:
        return 0xFF10B981;
      case ReadingStatus.finished:
        return 0xFFF59E0B;
    }
  }
}

enum ReadingFormat {
  book,
  ebook,
  article,
  study,
}

extension ReadingFormatExt on ReadingFormat {
  String get label {
    switch (this) {
      case ReadingFormat.book:
        return 'Book';
      case ReadingFormat.ebook:
        return 'E-Book';
      case ReadingFormat.article:
        return 'Article';
      case ReadingFormat.study:
        return 'Study';
    }
  }

  String get emoji {
    switch (this) {
      case ReadingFormat.book:
        return '📖';
      case ReadingFormat.ebook:
        return '📱';
      case ReadingFormat.article:
        return '📰';
      case ReadingFormat.study:
        return '📘';
    }
  }
}

class ReadingItem {
  final String id;
  final String title;
  final String author;
  final String category;
  final ReadingFormat format;
  final int currentPage;
  final int totalPages;
  final ReadingStatus status;
  final int? rating; // 1-5 stars
  final String? notes;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  ReadingItem({
    required this.id,
    required this.title,
    this.author = '',
    this.category = 'General',
    this.format = ReadingFormat.book,
    this.currentPage = 0,
    required this.totalPages,
    this.status = ReadingStatus.wantToRead,
    this.rating,
    this.notes,
    this.startedAt,
    this.finishedAt,
    required this.createdAt,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  /// Safe clamped current page within [0, totalPages] (0 if totalPages <= 0).
  int get safeCurrentPage => totalPages > 0 ? currentPage.clamp(0, totalPages) : 0;

  /// Fraction in [0.0, 1.0] with zero-division protection.
  double get progressFraction {
    if (totalPages <= 0) return 0.0;
    return (currentPage / totalPages).clamp(0.0, 1.0);
  }

  /// Exact percentage completion in [0.0, 100.0].
  double get exactPercentage => progressFraction * 100.0;

  /// Rounded integer percentage completion in [0, 100].
  int get percentageCompletion => exactPercentage.round().clamp(0, 100);

  String get formattedPercentage => '$percentageCompletion%';

  int get pagesRemaining =>
      totalPages > 0 ? (totalPages - safeCurrentPage).clamp(0, totalPages) : 0;

  bool get isCompleted =>
      status == ReadingStatus.finished ||
      (totalPages > 0 && currentPage >= totalPages);

  String get formattedProgress =>
      '$safeCurrentPage / $totalPages pages ($percentageCompletion%)';

  ReadingItem copyWith({
    String? id,
    String? title,
    String? author,
    String? category,
    ReadingFormat? format,
    int? currentPage,
    int? totalPages,
    ReadingStatus? status,
    int? rating,
    bool clearRating = false,
    String? notes,
    bool clearNotes = false,
    DateTime? startedAt,
    bool clearStartedAt = false,
    DateTime? finishedAt,
    bool clearFinishedAt = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReadingItem(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      category: category ?? this.category,
      format: format ?? this.format,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      status: status ?? this.status,
      rating: clearRating ? null : (rating ?? this.rating),
      notes: clearNotes ? null : (notes ?? this.notes),
      startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
      finishedAt: clearFinishedAt ? null : (finishedAt ?? this.finishedAt),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'category': category,
      'format': format.name,
      'currentPage': currentPage,
      'totalPages': totalPages,
      'status': status.name,
      'rating': rating,
      'notes': notes,
      'startedAt': startedAt?.toIso8601String(),
      'finishedAt': finishedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ReadingItem.fromJson(Map<String, dynamic> json) {
    final formatName = json['format'] as String? ?? 'book';
    final parsedFormat = ReadingFormat.values.firstWhere(
      (f) => f.name == formatName,
      orElse: () => ReadingFormat.book,
    );

    final statusName = json['status'] as String? ?? 'wantToRead';
    final parsedStatus = ReadingStatus.values.firstWhere(
      (s) => s.name == statusName,
      orElse: () => ReadingStatus.wantToRead,
    );

    final created = json['createdAt'] != null
        ? (DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now())
        : DateTime.now();

    return ReadingItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled Book',
      author: json['author'] as String? ?? '',
      category: json['category'] as String? ?? 'General',
      format: parsedFormat,
      currentPage: (json['currentPage'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
      status: parsedStatus,
      rating: (json['rating'] as num?)?.toInt(),
      notes: json['notes'] as String?,
      startedAt: json['startedAt'] != null
          ? DateTime.tryParse(json['startedAt'] as String)
          : null,
      finishedAt: json['finishedAt'] != null
          ? DateTime.tryParse(json['finishedAt'] as String)
          : null,
      createdAt: created,
      updatedAt: json['updatedAt'] != null
          ? (DateTime.tryParse(json['updatedAt'] as String) ?? created)
          : created,
    );
  }
}

