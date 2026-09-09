/// 몰입 모드 판정 — 집중 중 일정 시간 무조작이면 화면을 순수 검정으로 바꾼다.
///
/// 왜: 120분짜리 화면에서 배너·링·버튼은 전부 빛이고 빛은 전력이다. OLED 에서 검정 픽셀은
/// 꺼진 픽셀이다. 그리고 "볼 것이 없는" 화면이 집중을 덜 방해한다.
///
/// 순수 함수만. 위젯 쪽([ImmersionShell])이 마지막 조작 시각을 기록하고 여기에 묻는다.
abstract final class ImmersionRules {
  /// 마지막 조작 후 이 시간이 지나면 몰입으로 들어간다.
  static const Duration idleThreshold = Duration(seconds: 15);

  /// 몰입 진입 여부.
  ///
  /// [enabled] 가 false 면 절대 들어가지 않는다 (설정으로 끄는 경로).
  /// [lastInteraction] 이 null 이면 아직 화면이 뜬 직후로 보고 [screenShownAt] 을 기준으로 잰다.
  static bool shouldEnter({
    required bool enabled,
    required DateTime now,
    required DateTime screenShownAt,
    DateTime? lastInteraction,
    Duration threshold = idleThreshold,
  }) {
    if (!enabled) return false;
    final DateTime anchor = lastInteraction ?? screenShownAt;
    final Duration idle = now.difference(anchor);
    if (idle.isNegative) return false; // 시각 역행(기기 시각 변경) — 판단 보류
    return idle >= threshold;
  }

  /// 몰입 중 표시할 잔여 시간 문자열. 시 단위가 필요하면 `h:mm:ss`, 아니면 `mm:ss`.
  static String timerLabel(int remainingSeconds) {
    final int s = remainingSeconds < 0 ? 0 : remainingSeconds;
    final int h = s ~/ 3600;
    final int m = (s % 3600) ~/ 60;
    final int sec = s % 60;
    final String mm = m.toString().padLeft(2, '0');
    final String ss = sec.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }
}
