import 'package:flutter_test/flutter_test.dart';
import 'package:focus_cash/domain/focus_day.dart';

void main() {
  group('effectiveTodayFocusMinutes', () {
    // 2026-09-09 00:30 KST = 2026-09-08 15:30 UTC
    final DateTime wedKst = DateTime.utc(2026, 9, 8, 15, 30);

    test('focusDate matches today → keep minutes', () {
      expect(
        effectiveTodayFocusMinutes(
          todayFocusMinutes: 1080,
          focusDate: '2026-09-09',
          now: wedKst,
        ),
        1080,
      );
    });

    test('focusDate is yesterday → 0 (stale counter)', () {
      expect(
        effectiveTodayFocusMinutes(
          todayFocusMinutes: 1080,
          focusDate: '2026-09-08',
          now: wedKst,
        ),
        0,
      );
    });

    test('empty focusDate → 0', () {
      expect(
        effectiveTodayFocusMinutes(
          todayFocusMinutes: 50,
          focusDate: '',
          now: wedKst,
        ),
        0,
      );
    });
  });

  test('focusDateKey 는 서버와 같이 KST(UTC+540) 달력이다', () {
    expect(focusDateKey(DateTime.utc(2026, 9, 8, 15, 0)), '2026-09-09');
    expect(focusDateKey(DateTime.utc(2026, 9, 8, 14, 59)), '2026-09-08');
    expect(focusDateKey(DateTime.utc(2026, 1, 4, 15, 0)), '2026-01-05');
  });
}
