/// 오늘 집중 분의 날짜 키와 화면용 유효값.
///
/// Firestore `users.focusDate` / `todayFocusMinutes` 는 다음 완료 전까지
/// 어제 값이 그대로 남을 수 있다. 읽기 시점에 날짜가 다르면 0으로 본다.
library;

/// 한국 달력 날짜 `YYYY-MM-DD`. 서버 `dateKey`(UTC+540) 와 같다.
///
/// 기기 로컬 타임존으로 자르면 서버 정산 스위치 이후 오늘 분이 0으로 보일 수 있다.
String focusDateKey(DateTime d, {int tzOffsetMinutes = 540}) {
  final DateTime kst = d.toUtc().add(Duration(minutes: tzOffsetMinutes));
  return '${kst.year}-${kst.month.toString().padLeft(2, '0')}-${kst.day.toString().padLeft(2, '0')}';
}

/// [focusDate] 가 [now] 의 날짜와 같을 때만 [todayFocusMinutes] 를 쓰고, 아니면 0.
int effectiveTodayFocusMinutes({
  required int todayFocusMinutes,
  required String focusDate,
  DateTime? now,
}) {
  final DateTime n = now ?? DateTime.now();
  return focusDate == focusDateKey(n) ? todayFocusMinutes : 0;
}
