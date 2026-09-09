import 'package:flutter_test/flutter_test.dart';
import 'package:focus_cash/domain/immersion_rules.dart';

void main() {
  final DateTime shown = DateTime(2026, 9, 9, 14, 0, 0);

  group('ImmersionRules.shouldEnter', () {
    test('꺼져 있으면 절대 들어가지 않는다', () {
      expect(
        ImmersionRules.shouldEnter(
          enabled: false,
          now: shown.add(const Duration(minutes: 5)),
          screenShownAt: shown,
        ),
        isFalse,
      );
    });

    test('조작이 없으면 화면이 뜬 시각 기준으로 15초 뒤 진입', () {
      expect(
        ImmersionRules.shouldEnter(
          enabled: true,
          now: shown.add(const Duration(seconds: 14)),
          screenShownAt: shown,
        ),
        isFalse,
      );
      expect(
        ImmersionRules.shouldEnter(
          enabled: true,
          now: shown.add(const Duration(seconds: 15)),
          screenShownAt: shown,
        ),
        isTrue,
      );
    });

    test('마지막 조작이 기준을 당긴다', () {
      final DateTime touched = shown.add(const Duration(seconds: 40));
      expect(
        ImmersionRules.shouldEnter(
          enabled: true,
          now: touched.add(const Duration(seconds: 10)),
          screenShownAt: shown,
          lastInteraction: touched,
        ),
        isFalse,
      );
      expect(
        ImmersionRules.shouldEnter(
          enabled: true,
          now: touched.add(const Duration(seconds: 15)),
          screenShownAt: shown,
          lastInteraction: touched,
        ),
        isTrue,
      );
    });

    test('시각이 역행하면 판단을 보류한다', () {
      expect(
        ImmersionRules.shouldEnter(
          enabled: true,
          now: shown.subtract(const Duration(minutes: 1)),
          screenShownAt: shown,
        ),
        isFalse,
      );
    });
  });

  group('ImmersionRules.timerLabel', () {
    test('한 시간 미만은 mm:ss', () {
      expect(ImmersionRules.timerLabel(0), '00:00');
      expect(ImmersionRules.timerLabel(65), '01:05');
      expect(ImmersionRules.timerLabel(3599), '59:59');
    });

    test('한 시간 이상은 h:mm:ss', () {
      expect(ImmersionRules.timerLabel(3600), '1:00:00');
      expect(ImmersionRules.timerLabel(7199), '1:59:59');
    });

    test('음수는 0 으로', () {
      expect(ImmersionRules.timerLabel(-5), '00:00');
    });
  });

  test('dimBrightness 는 꺼지지 않게 낮고, 타이머는 읽히게 둔다', () {
    expect(ImmersionRules.dimBrightness, greaterThan(0));
    expect(ImmersionRules.dimBrightness, lessThanOrEqualTo(0.1));
  });
}
