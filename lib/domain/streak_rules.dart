/// 스트릭 판정 결과.
class StreakResult {
  const StreakResult({
    required this.currentStreak,
    required this.longestStreak,
    required this.counted,
  });

  final int currentStreak;
  final int longestStreak;

  /// 오늘 첫 완료라서 스트릭 계산에 반영됐는지. false 면 값이 그대로다.
  final bool counted;
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// 집중 완료 시 스트릭을 계산한다.
///
/// 기준은 **마지막 집중 완료일**([lastFocusDate])이어야 한다. `lastActiveAt` 처럼
/// 룰렛·광고 보너스에도 갱신되는 필드를 쓰면, 룰렛만 돌린 날이 연속으로 인정되거나
/// 룰렛 후 집중을 완료했을 때 스트릭이 오르지 않는다.
StreakResult computeStreak({
  required DateTime today,
  required DateTime? lastFocusDate,
  required int currentStreak,
  required int longestStreak,
}) {
  if (lastFocusDate != null && isSameDay(lastFocusDate, today)) {
    return StreakResult(
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      counted: false,
    );
  }

  final DateTime todayDate = DateTime(today.year, today.month, today.day);
  final DateTime yesterday = todayDate.subtract(const Duration(days: 1));
  final bool consecutive =
      lastFocusDate != null && isSameDay(lastFocusDate, yesterday);

  final int next = consecutive ? currentStreak + 1 : 1;
  return StreakResult(
    currentStreak: next,
    longestStreak: next > longestStreak ? next : longestStreak,
    counted: true,
  );
}
