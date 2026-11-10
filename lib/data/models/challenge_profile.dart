enum ChallengeType {
  math,
  memory,
  typing,
}

enum ChallengeDifficulty {
  easy,
  medium,
  hard,
}

class WakeUpChallengeProfile {
  final String id;
  final bool isEnabled;
  final ChallengeType type;
  final ChallengeDifficulty difficulty;
  final int questionsCount; // e.g. 1 to 5
  final bool allowSnoozeDuringChallenge;

  const WakeUpChallengeProfile({
    required this.id,
    this.isEnabled = false,
    this.type = ChallengeType.math,
    this.difficulty = ChallengeDifficulty.easy,
    this.questionsCount = 3,
    this.allowSnoozeDuringChallenge = true,
  });

  /// Factory for the system default profile
  factory WakeUpChallengeProfile.defaultProfile() {
    return const WakeUpChallengeProfile(
      id: 'global_default',
      isEnabled: true,
      type: ChallengeType.math,
      difficulty: ChallengeDifficulty.easy,
      questionsCount: 3,
      allowSnoozeDuringChallenge: true,
    );
  }

  WakeUpChallengeProfile copyWith({
    String? id,
    bool? isEnabled,
    ChallengeType? type,
    ChallengeDifficulty? difficulty,
    int? questionsCount,
    bool? allowSnoozeDuringChallenge,
  }) {
    return WakeUpChallengeProfile(
      id: id ?? this.id,
      isEnabled: isEnabled ?? this.isEnabled,
      type: type ?? this.type,
      difficulty: difficulty ?? this.difficulty,
      questionsCount: questionsCount ?? this.questionsCount,
      allowSnoozeDuringChallenge:
          allowSnoozeDuringChallenge ?? this.allowSnoozeDuringChallenge,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'isEnabled': isEnabled,
      'type': type.name,
      'difficulty': difficulty.name,
      'questionsCount': questionsCount,
      'allowSnoozeDuringChallenge': allowSnoozeDuringChallenge,
    };
  }

  factory WakeUpChallengeProfile.fromJson(Map<String, dynamic> json) {
    return WakeUpChallengeProfile(
      id: json['id'] as String? ?? 'profile',
      isEnabled: json['isEnabled'] as bool? ?? false,
      type: ChallengeType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ChallengeType.math,
      ),
      difficulty: ChallengeDifficulty.values.firstWhere(
        (e) => e.name == json['difficulty'],
        orElse: () => ChallengeDifficulty.easy,
      ),
      questionsCount: json['questionsCount'] as int? ?? 3,
      allowSnoozeDuringChallenge:
          json['allowSnoozeDuringChallenge'] as bool? ?? true,
    );
  }

  String get typeLabel {
    switch (type) {
      case ChallengeType.math:
        return 'Math Problems';
      case ChallengeType.memory:
        return 'Pattern Memory';
      case ChallengeType.typing:
        return 'Word Typing';
    }
  }

  String get difficultyLabel {
    switch (difficulty) {
      case ChallengeDifficulty.easy:
        return 'Easy';
      case ChallengeDifficulty.medium:
        return 'Medium';
      case ChallengeDifficulty.hard:
        return 'Hard';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WakeUpChallengeProfile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          isEnabled == other.isEnabled &&
          type == other.type &&
          difficulty == other.difficulty &&
          questionsCount == other.questionsCount &&
          allowSnoozeDuringChallenge == other.allowSnoozeDuringChallenge;

  @override
  int get hashCode => Object.hash(
        id,
        isEnabled,
        type,
        difficulty,
        questionsCount,
        allowSnoozeDuringChallenge,
      );
}

