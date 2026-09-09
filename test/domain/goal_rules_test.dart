import 'package:flutter_test/flutter_test.dart';
import 'package:focus_cash/config/constants.dart';
import 'package:focus_cash/domain/goal_rules.dart';

void main() {
  group('GoalRules.normalize', () {
    test('30분 단위로 내림하고 범위를 지킨다', () {
      expect(GoalRules.normalize(240), 240);
      expect(GoalRules.normalize(245), 240);
      expect(GoalRules.normalize(10), 30);
      expect(GoalRules.normalize(9999), 480);
    });

    test('0 이하면 기본값', () {
      expect(GoalRules.normalize(0), AppConstants.dailyGoalMinutes);
      expect(GoalRules.normalize(-5), AppConstants.dailyGoalMinutes);
    });

    test('기본값 자체가 규칙을 만족한다', () {
      expect(GoalRules.normalize(GoalRules.defaultMinutes),
          GoalRules.defaultMinutes);
    });
  });

  group('GoalRules.progress', () {
    test('0~1 로 자른다', () {
      expect(GoalRules.progress(todayMinutes: 60, goalMinutes: 240), 0.25);
      expect(GoalRules.progress(todayMinutes: 500, goalMinutes: 240), 1.0);
      expect(GoalRules.progress(todayMinutes: 0, goalMinutes: 0), 0.0);
    });
  });

  group('GoalRules.label', () {
    test('시간·분 표기', () {
      expect(GoalRules.label(30), '30분');
      expect(GoalRules.label(60), '1시간');
      expect(GoalRules.label(90), '1시간 30분');
      expect(GoalRules.label(480), '8시간');
    });
  });
}
