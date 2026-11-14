import 'dart:math';
import '../../data/models/challenge_profile.dart';

class MathQuestion {
  final String questionText;
  final int correctAnswer;

  MathQuestion({required this.questionText, required this.correctAnswer});
}

class ChallengeEngine {
  static final Random _random = Random();

  // Math Challenge
  static MathQuestion generateMathQuestion(ChallengeDifficulty difficulty) {
    switch (difficulty) {
      case ChallengeDifficulty.easy:
        final a = _random.nextInt(30) + 5;
        final b = _random.nextInt(30) + 5;
        final isAdd = _random.nextBool();
        if (isAdd) {
          return MathQuestion(
            questionText: '$a + $b = ?',
            correctAnswer: a + b,
          );
        } else {
          final maxVal = max(a, b);
          final minVal = min(a, b);
          return MathQuestion(
            questionText: '$maxVal - $minVal = ?',
            correctAnswer: maxVal - minVal,
          );
        }

      case ChallengeDifficulty.medium:
        final op = _random.nextInt(3);
        if (op == 0) {
          // Multiplication
          final a = _random.nextInt(10) + 3;
          final b = _random.nextInt(10) + 3;
          return MathQuestion(
            questionText: '$a × $b = ?',
            correctAnswer: a * b,
          );
        } else if (op == 1) {
          // 3-term addition/subtraction
          final a = _random.nextInt(40) + 10;
          final b = _random.nextInt(30) + 10;
          final c = _random.nextInt(20) + 5;
          return MathQuestion(
            questionText: '$a + $b - $c = ?',
            correctAnswer: a + b - c,
          );
        } else {
          final a = _random.nextInt(60) + 20;
          final b = _random.nextInt(40) + 10;
          return MathQuestion(
            questionText: '$a + $b = ?',
            correctAnswer: a + b,
          );
        }

      case ChallengeDifficulty.hard:
        final op = _random.nextInt(2);
        if (op == 0) {
          // (a * b) + c
          final a = _random.nextInt(12) + 6;
          final b = _random.nextInt(10) + 4;
          final c = _random.nextInt(50) + 10;
          return MathQuestion(
            questionText: '($a × $b) + $c = ?',
            correctAnswer: (a * b) + c,
          );
        } else {
          // (a * b) - c
          final a = _random.nextInt(12) + 6;
          final b = _random.nextInt(10) + 5;
          final c = _random.nextInt(30) + 5;
          return MathQuestion(
            questionText: '($a × $b) - $c = ?',
            correctAnswer: (a * b) - c,
          );
        }
    }
  }

  // Memory Challenge (Sequence of numbers 1-4)
  static List<int> generateMemorySequence(ChallengeDifficulty difficulty) {
    int length = 4;
    if (difficulty == ChallengeDifficulty.medium) length = 5;
    if (difficulty == ChallengeDifficulty.hard) length = 7;

    return List.generate(length, (_) => _random.nextInt(4));
  }

  // Typing Challenge Phrases
  static const List<String> _easyPhrases = [
    'Rise and shine today',
    'Right on time',
    'Wake up with energy',
    'Morning brings success',
  ];

  static const List<String> _mediumPhrases = [
    'Every moment, right on time with Nestin.',
    'A disciplined morning makes a victorious day.',
    'Wake up early and chase your highest goals.',
  ];

  static const List<String> _hardPhrases = [
    'Persistence guarantees that the results of the dawn surpass yesterday.',
    'Master your time, focus your mind, and make every single second count.',
  ];

  static String generateTypingPhrase(ChallengeDifficulty difficulty) {
    switch (difficulty) {
      case ChallengeDifficulty.easy:
        return _easyPhrases[_random.nextInt(_easyPhrases.length)];
      case ChallengeDifficulty.medium:
        return _mediumPhrases[_random.nextInt(_mediumPhrases.length)];
      case ChallengeDifficulty.hard:
        return _hardPhrases[_random.nextInt(_hardPhrases.length)];
    }
  }
}

