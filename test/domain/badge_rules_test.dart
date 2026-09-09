import 'package:flutter_test/flutter_test.dart';
import 'package:focus_cash/domain/badge_rules.dart';

BadgeInput _base({
  int totalMinutesBefore = 1000,
  int actualMinutes = 30,
  int streakAfter = 1,
  int hardcoreCountAfter = 0,
  int todayMinutesBefore = 0,
  DateTime? startedAt,
  int oldLevel = 3,
  int newLevel = 3,
  List<String> existing = const [],
}) =>
    BadgeInput(
      totalMinutesBefore: totalMinutesBefore,
      actualMinutes: actualMinutes,
      streakAfter: streakAfter,
      hardcoreCountAfter: hardcoreCountAfter,
      todayMinutesBefore: todayMinutesBefore,
      startedAt: startedAt ?? DateTime(2026, 9, 9, 14),
      oldLevel: oldLevel,
      newLevel: newLevel,
      existingBadges: existing,
    );

void main() {
  group('evaluateBadges', () {
    test('첫 세션(누적 0분)에만 first_focus', () {
      expect(evaluateBadges(_base(totalMinutesBefore: 0)), contains('first_focus'));
      expect(evaluateBadges(_base(totalMinutesBefore: 10)),
          isNot(contains('first_focus')));
    });

    test('누적 600분 도달 시 focus_10h, 6000분 도달 시 focus_100h', () {
      expect(evaluateBadges(_base(totalMinutesBefore: 570, actualMinutes: 30)),
          contains('focus_10h'));
      expect(evaluateBadges(_base(totalMinutesBefore: 5990, actualMinutes: 10)),
          containsAll(['focus_10h', 'focus_100h']));
    });

    test('스트릭 7일·30일 배지는 갱신된 스트릭으로 판정한다', () {
      expect(evaluateBadges(_base(streakAfter: 7)), contains('streak_7'));
      expect(evaluateBadges(_base(streakAfter: 6)), isNot(contains('streak_7')));
      expect(evaluateBadges(_base(streakAfter: 30)), contains('streak_30'));
    });

    test('하드코어 10회 완료 시 hardcore_10', () {
      expect(evaluateBadges(_base(hardcoreCountAfter: 10)), contains('hardcore_10'));
      expect(evaluateBadges(_base(hardcoreCountAfter: 9)),
          isNot(contains('hardcore_10')));
    });

    test('오전 6시 이전 시작은 early_bird, 23시~01시 시작은 night_owl', () {
      expect(evaluateBadges(_base(startedAt: DateTime(2026, 9, 9, 5, 59))),
          contains('early_bird'));
      expect(evaluateBadges(_base(startedAt: DateTime(2026, 9, 9, 23, 10))),
          contains('night_owl'));
      expect(evaluateBadges(_base(startedAt: DateTime(2026, 9, 9, 0, 30))),
          containsAll(['night_owl', 'early_bird']));
      expect(evaluateBadges(_base(startedAt: DateTime(2026, 9, 9, 12))),
          isNot(anyOf(contains('early_bird'), contains('night_owl'))));
    });

    test('하루 120분 도달 시 full_day', () {
      expect(evaluateBadges(_base(todayMinutesBefore: 90, actualMinutes: 30)),
          contains('full_day'));
    });

    test('레벨 5·10을 이번에 넘었을 때만 레벨 배지', () {
      expect(evaluateBadges(_base(oldLevel: 4, newLevel: 5)), contains('level_5'));
      expect(evaluateBadges(_base(oldLevel: 5, newLevel: 6)),
          isNot(contains('level_5')));
      expect(evaluateBadges(_base(oldLevel: 9, newLevel: 11)), contains('level_10'));
    });

    test('이미 가진 배지는 다시 주지 않는다', () {
      expect(
        evaluateBadges(_base(streakAfter: 7, existing: ['streak_7'])),
        isNot(contains('streak_7')),
      );
    });

    test('결과에 중복이 없다', () {
      final r = evaluateBadges(_base(totalMinutesBefore: 0, streakAfter: 30));
      expect(r.toSet().length, r.length);
    });
  });

  group('xpForSession', () {
    test('분당 1 XP, 하드코어는 1.2배 반올림', () {
      expect(xpForSession(actualMinutes: 50, isHardcore: false), 50);
      expect(xpForSession(actualMinutes: 50, isHardcore: true), 60);
      expect(xpForSession(actualMinutes: 0, isHardcore: true), 0);
    });
  });
}
