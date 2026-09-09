/// 오늘 집중 분의 날짜 키와 화면용 유효값.
///
/// Firestore `users.focusDate` / `todayFocusMinutes` 는 다음 완료 전까지
/// 어제 값이 그대로 남을 수 있다. 읽기 시점에 날짜가 다르면 0으로 본다.
library;

String focusDateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// [focusDate] 가 [now] 의 날짜와 같을 때만 [todayFocusMinutes] 를 쓰고, 아니면 0.
int effectiveTodayFocusMinutes({
  required int todayFocusMinutes,
  required String focusDate,
  DateTime? now,
}) {
  final DateTime n = now ?? DateTime.now();
  return focusDate == focusDateKey(n) ? todayFocusMinutes : 0;
}
