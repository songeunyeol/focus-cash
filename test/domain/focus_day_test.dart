import 'package:flutter_test/flutter_test.dart';
import 'package:focus_cash/domain/focus_day.dart';

void main() {
  group('effectiveTodayFocusMinutes', () {
    final DateTime wed = DateTime(2026, 9, 9, 15, 30);

    test('focusDate matches today → keep minutes', () {
      expect(
        effectiveTodayFocusMinutes(
          todayFocusMinutes: 1080,
          focusDate: '2026-09-09',
          now: wed,
        ),
        1080,
      );
    });

    test('focusDate is yesterday → 0 (stale counter)', () {
      expect(
        effectiveTodayFocusMinutes(
          todayFocusMinutes: 1080,
          focusDate: '2026-09-08',
          now: wed,
        ),
        0,
      );
    });

    test('empty focusDate → 0', () {
      expect(
        effectiveTodayFocusMinutes(
          todayFocusMinutes: 50,
          focusDate: '',
          now: wed,
        ),
        0,
      );
    });
  });

  test('focusDateKey zero-pads', () {
    expect(focusDateKey(DateTime(2026, 9, 9)), '2026-09-09');
    expect(focusDateKey(DateTime(2026, 1, 5)), '2026-01-05');
  });
}
