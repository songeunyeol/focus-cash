import '../config/constants.dart';

/// 하루 집중 목표(분) 규칙. 순수 함수만.
abstract final class GoalRules {
  static const int minMinutes = 30;
  static const int maxMinutes = 480;
  static const int stepMinutes = 30;
  static int get defaultMinutes => AppConstants.dailyGoalMinutes;

  /// 범위(30~480)로 자르고 30분 단위로 내림한다. 잘못된 값(0·음수)은 기본값.
  static int normalize(int minutes) {
    if (minutes <= 0) return defaultMinutes;
    final int clamped = minutes.clamp(minMinutes, maxMinutes);
    return (clamped ~/ stepMinutes) * stepMinutes;
  }

  /// 목표 대비 진행률 0.0~1.0. 목표가 0 이면 0.
  static double progress({required int todayMinutes, required int goalMinutes}) {
    if (goalMinutes <= 0) return 0;
    final double p = todayMinutes / goalMinutes;
    return p < 0 ? 0 : (p > 1 ? 1 : p);
  }

  /// "4시간" / "1시간 30분" / "30분"
  static String label(int minutes) {
    final int h = minutes ~/ 60;
    final int m = minutes % 60;
    if (h == 0) return '$m분';
    if (m == 0) return '$h시간';
    return '$h시간 $m분';
  }
}
