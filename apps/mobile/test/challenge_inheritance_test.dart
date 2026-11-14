import 'package:flutter_test/flutter_test.dart';
import 'package:nestin/data/models/alarm.dart';
import 'package:nestin/data/models/alarm_category.dart';
import 'package:nestin/data/models/alarm_schedule.dart';
import 'package:nestin/data/models/challenge_profile.dart';

void main() {
  group('Wake-Up Challenge Inheritance Tests', () {
    final globalDefault = WakeUpChallengeProfile(
      id: 'global_default',
      isEnabled: true,
      type: ChallengeType.math,
      difficulty: ChallengeDifficulty.easy,
      questionsCount: 3,
      allowSnoozeDuringChallenge: true,
    );

    test('Newly created wake-up alarm inherits current global default challenge profile', () {
      final alarm = Alarm(
        id: 'alarm_1',
        title: 'Morning Wakeup',
        hour: 7,
        minute: 0,
        category: AlarmCategory.fromType(AlarmCategoryType.wakeUp),
        schedule: AlarmSchedule.daily(),
        challengeInherited: true,
        challengeOverride: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final effective = alarm.effectiveChallenge(globalDefault);
      expect(effective.type, ChallengeType.math);
      expect(effective.difficulty, ChallengeDifficulty.easy);
      expect(effective.questionsCount, 3);
    });

    test('Updating global profile dynamically updates alarms that inherit defaults', () {
      final alarm = Alarm(
        id: 'alarm_1',
        title: 'Morning Wakeup',
        hour: 7,
        minute: 0,
        category: AlarmCategory.fromType(AlarmCategoryType.wakeUp),
        schedule: AlarmSchedule.daily(),
        challengeInherited: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final updatedGlobal = globalDefault.copyWith(
        type: ChallengeType.memory,
        difficulty: ChallengeDifficulty.hard,
        questionsCount: 5,
      );

      final effective = alarm.effectiveChallenge(updatedGlobal);
      expect(effective.type, ChallengeType.memory);
      expect(effective.difficulty, ChallengeDifficulty.hard);
      expect(effective.questionsCount, 5);
    });

    test('Alarms with individual overrides protect their settings against global changes', () {
      final customOverride = WakeUpChallengeProfile(
        id: 'custom_override',
        isEnabled: true,
        type: ChallengeType.typing,
        difficulty: ChallengeDifficulty.medium,
        questionsCount: 1,
        allowSnoozeDuringChallenge: false,
      );

      final alarm = Alarm(
        id: 'alarm_override',
        title: 'Super Strict Alarm',
        hour: 6,
        minute: 0,
        category: AlarmCategory.fromType(AlarmCategoryType.wakeUp),
        schedule: AlarmSchedule.daily(),
        challengeInherited: false,
        challengeOverride: customOverride,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Global defaults change
      final updatedGlobal = globalDefault.copyWith(
        type: ChallengeType.math,
        difficulty: ChallengeDifficulty.easy,
      );

      final effective = alarm.effectiveChallenge(updatedGlobal);
      // Must retain typing medium, not change to math easy!
      expect(effective.type, ChallengeType.typing);
      expect(effective.difficulty, ChallengeDifficulty.medium);
      expect(effective.allowSnoozeDuringChallenge, false);
    });

    test('Resetting individual alarm reverts to inheriting global defaults', () {
      final customOverride = WakeUpChallengeProfile(
        id: 'custom_override',
        isEnabled: true,
        type: ChallengeType.typing,
        difficulty: ChallengeDifficulty.hard,
      );

      var alarm = Alarm(
        id: 'alarm_2',
        title: 'Work Alert',
        hour: 8,
        minute: 0,
        category: AlarmCategory.fromType(AlarmCategoryType.wakeUp),
        schedule: AlarmSchedule.daily(),
        challengeInherited: false,
        challengeOverride: customOverride,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(alarm.effectiveChallenge(globalDefault).type, ChallengeType.typing);

      // User resets to global
      alarm = alarm.copyWith(
        challengeInherited: true,
        clearChallengeOverride: true,
      );

      expect(alarm.effectiveChallenge(globalDefault).type, ChallengeType.math);
    });

    test('Non-wake-up alarms do not enforce challenge unless specifically customized', () {
      final meetingAlarm = Alarm(
        id: 'meeting_alarm',
        title: 'Client Standup',
        hour: 14,
        minute: 0,
        category: AlarmCategory.fromType(AlarmCategoryType.work),
        schedule: AlarmSchedule.weekdays(),
        challengeInherited: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final effective = meetingAlarm.effectiveChallenge(globalDefault);
      expect(effective.isEnabled, false);
    });
  });
}

