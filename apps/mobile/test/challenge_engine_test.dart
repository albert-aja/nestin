import 'package:flutter_test/flutter_test.dart';
import 'package:nestin/data/models/challenge_profile.dart';
import 'package:nestin/domain/challenge/challenge_engine.dart';

void main() {
  group('ChallengeEngine Tests', () {
    test('Generates valid math questions with correct answers', () {
      for (int i = 0; i < 20; i++) {
        final easyQ = ChallengeEngine.generateMathQuestion(ChallengeDifficulty.easy);
        expect(easyQ.questionText, contains('?'));
        expect(easyQ.correctAnswer, isNotNull);

        final medQ = ChallengeEngine.generateMathQuestion(ChallengeDifficulty.medium);
        expect(medQ.questionText, contains('?'));

        final hardQ = ChallengeEngine.generateMathQuestion(ChallengeDifficulty.hard);
        expect(hardQ.questionText, contains('?'));
      }
    });

    test('Generates memory sequence matching difficulty length', () {
      final easySeq = ChallengeEngine.generateMemorySequence(ChallengeDifficulty.easy);
      expect(easySeq.length, 4);
      for (final val in easySeq) {
        expect(val >= 0 && val < 4, isTrue);
      }

      final medSeq = ChallengeEngine.generateMemorySequence(ChallengeDifficulty.medium);
      expect(medSeq.length, 5);

      final hardSeq = ChallengeEngine.generateMemorySequence(ChallengeDifficulty.hard);
      expect(hardSeq.length, 7);
    });

    test('Generates typing challenge phrases', () {
      final phrase = ChallengeEngine.generateTypingPhrase(ChallengeDifficulty.easy);
      expect(phrase.isNotEmpty, isTrue);
    });
  });
}

