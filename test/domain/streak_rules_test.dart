import 'package:flutter_test/flutter_test.dart';
import 'package:focus_cash/domain/streak_rules.dart';

void main() {
  final today = DateTime(2026, 9, 9);

  group('computeStreak', () {
    test('첫 집중이면 스트릭 1로 시작한다', () {
      final r = computeStreak(
        today: today,
        lastFocusDate: null,
        currentStreak: 0,
        longestStreak: 0,
      );
      expect(r.currentStreak, 1);
      expect(r.longestStreak, 1);
      expect(r.counted, isTrue);
    });

    test('어제 집중했으면 +1', () {
      final r = computeStreak(
        today: today,
        lastFocusDate: DateTime(2026, 9, 8, 23, 59),
        currentStreak: 4,
        longestStreak: 10,
      );
      expect(r.currentStreak, 5);
      expect(r.longestStreak, 10);
    });

    test('하루 이상 건너뛰면 1로 리셋', () {
      final r = computeStreak(
        today: today,
        lastFocusDate: DateTime(2026, 9, 7),
        currentStreak: 4,
        longestStreak: 4,
      );
      expect(r.currentStreak, 1);
      expect(r.longestStreak, 4);
    });

    test('오늘 이미 집중했으면 변화 없음 (counted=false)', () {
      final r = computeStreak(
        today: today,
        lastFocusDate: DateTime(2026, 9, 9, 8),
        currentStreak: 4,
        longestStreak: 4,
      );
      expect(r.currentStreak, 4);
      expect(r.counted, isFalse);
    });

    test('최장 스트릭은 현재가 넘어설 때만 갱신된다', () {
      final r = computeStreak(
        today: today,
        lastFocusDate: DateTime(2026, 9, 8),
        currentStreak: 10,
        longestStreak: 10,
      );
      expect(r.longestStreak, 11);
    });

    test('월 경계를 넘어도 연속으로 인정한다', () {
      final r = computeStreak(
        today: DateTime(2026, 10, 1),
        lastFocusDate: DateTime(2026, 9, 30, 22),
        currentStreak: 1,
        longestStreak: 1,
      );
      expect(r.currentStreak, 2);
    });
  });

  group('isSameDay', () {
    test('시각이 달라도 같은 날이면 true', () {
      expect(isSameDay(DateTime(2026, 1, 1, 0, 1), DateTime(2026, 1, 1, 23, 59)),
          isTrue);
      expect(isSameDay(DateTime(2026, 1, 1, 23, 59), DateTime(2026, 1, 2, 0, 0)),
          isFalse);
    });
  });
}
