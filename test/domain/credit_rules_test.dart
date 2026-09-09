import 'package:flutter_test/flutter_test.dart';
import 'package:focus_cash/domain/credit_rules.dart';

void main() {
  group('CreditRules.sessionCredits', () {
    test('10분당 10크레딧, 10분 미만 잔여분은 버린다', () {
      expect(CreditRules.sessionCredits(focusMinutes: 59), 50);
      expect(CreditRules.sessionCredits(focusMinutes: 60), 60);
      expect(CreditRules.sessionCredits(focusMinutes: 9), 0);
    });

    test('하드코어 완료는 기본 크레딧의 1.2배를 반올림한다', () {
      expect(
        CreditRules.sessionCredits(focusMinutes: 50, hardcoreMode: 'hardcore'),
        60,
      );
      expect(
        CreditRules.sessionCredits(focusMinutes: 10, hardcoreMode: 'hardcore'),
        12,
      );
    });

    test('일반 모드는 배율이 없다', () {
      expect(
        CreditRules.sessionCredits(focusMinutes: 50, hardcoreMode: 'normal'),
        50,
      );
    });

    test('시작 광고 시청은 플랫 보너스를 더한다', () {
      expect(
        CreditRules.sessionCredits(focusMinutes: 30, watchedStartAd: true),
        45,
      );
    });
  });

  group('CreditRules.endAdBonus', () {
    test('획득 크레딧의 20%를 반올림한다', () {
      expect(CreditRules.endAdBonus(60), 12);
      expect(CreditRules.endAdBonus(12), 2);
      expect(CreditRules.endAdBonus(0), 0);
    });
  });

  group('CreditRules.applyDailyCap', () {
    test('캡에 여유가 있으면 전액 지급한다', () {
      expect(
        CreditRules.applyDailyCap(todayCredits: 100, amount: 60, cap: 250),
        60,
      );
    });

    test('캡을 넘는 부분은 잘라낸다', () {
      expect(
        CreditRules.applyDailyCap(todayCredits: 220, amount: 60, cap: 250),
        30,
      );
    });

    test('이미 캡을 채웠으면 0을 돌려주고 음수가 되지 않는다', () {
      expect(
        CreditRules.applyDailyCap(todayCredits: 250, amount: 60, cap: 250),
        0,
      );
      expect(
        CreditRules.applyDailyCap(todayCredits: 300, amount: 60, cap: 250),
        0,
      );
    });

    test('캡이 null 이면 제한하지 않는다', () {
      expect(
        CreditRules.applyDailyCap(todayCredits: 9999, amount: 60, cap: null),
        60,
      );
    });
  });

  group('CreditRules.hardcorePenalty', () {
    test('세션 목표 크레딧 기준이 아니라 보유 잔액의 10%를 반올림한다 (현행 정책)', () {
      expect(CreditRules.hardcorePenalty(totalCredits: 1234), 123);
      expect(CreditRules.hardcorePenalty(totalCredits: 0), 0);
    });
  });
}
