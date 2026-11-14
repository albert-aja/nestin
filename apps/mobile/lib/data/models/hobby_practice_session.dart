class HobbyPracticeSession {
  final String id;
  final String hobbyId;
  final String hobbyName;
  final int durationMinutes;
  final DateTime sessionDate;
  final String? focusTag; // e.g. "Technique", "Repertoire", "Theory", "Drills", "Free Play"
  final String? notes;
  final int rating; // 1 to 5 stars
  final DateTime createdAt;

  const HobbyPracticeSession({
    required this.id,
    required this.hobbyId,
    required this.hobbyName,
    required this.durationMinutes,
    required this.sessionDate,
    this.focusTag,
    this.notes,
    this.rating = 5,
    required this.createdAt,
  });

  double get durationHours => durationMinutes / 60.0;

  String get formattedDuration {
    final hours = durationMinutes ~/ 60;
    final mins = durationMinutes % 60;
    if (hours > 0 && mins > 0) {
      return '${hours}h ${mins}m';
    } else if (hours > 0) {
      return '${hours}h';
    }
    return '${mins}m';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hobbyId': hobbyId,
      'hobbyName': hobbyName,
      'durationMinutes': durationMinutes,
      'sessionDate': sessionDate.toIso8601String(),
      'focusTag': focusTag,
      'notes': notes,
      'rating': rating,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory HobbyPracticeSession.fromJson(Map<String, dynamic> json) {
    return HobbyPracticeSession(
      id: json['id'] as String,
      hobbyId: json['hobbyId'] as String,
      hobbyName: json['hobbyName'] as String? ?? 'Practice Session',
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 30,
      sessionDate: json['sessionDate'] != null
          ? DateTime.parse(json['sessionDate'] as String)
          : DateTime.now(),
      focusTag: json['focusTag'] as String?,
      notes: json['notes'] as String?,
      rating: (json['rating'] as num?)?.toInt() ?? 5,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }
}

