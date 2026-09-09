import '../config/constants.dart';

/// 배지 판정에 필요한 입력. 전부 "이번 세션 반영 전" 값과 세션 자체 정보다.
class BadgeInput {
  const BadgeInput({
    required this.totalMinutesBefore,
    required this.actualMinutes,
    required this.streakAfter,
    required this.hardcoreCountAfter,
    required this.todayMinutesBefore,
    required this.startedAt,
    required this.oldLevel,
    required this.newLevel,
    required this.existingBadges,
  });

  final int totalMinutesBefore;
  final int actualMinutes;

  /// 이번 세션까지 반영한 스트릭
  final int streakAfter;

  /// 이번 세션까지 반영한 하드코어 완료 횟수
  final int hardcoreCountAfter;
  final int todayMinutesBefore;
  final DateTime startedAt;
  final int oldLevel;
  final int newLevel;
  final List<String> existingBadges;
}

/// 세션 완료로 새로 얻는 배지 id 목록. 이미 가진 것은 제외하고 중복이 없다.
List<String> evaluateBadges(BadgeInput i) {
  final List<String> out = <String>[];
  void give(String id) {
    if (!i.existingBadges.contains(id) && !out.contains(id)) out.add(id);
  }

  final int totalAfter = i.totalMinutesBefore + i.actualMinutes;

  if (i.totalMinutesBefore == 0) give('first_focus');
  if (totalAfter >= 600) give('focus_10h');
  if (totalAfter >= 6000) give('focus_100h');
  if (i.streakAfter >= 7) give('streak_7');
  if (i.streakAfter >= 30) give('streak_30');
  if (i.hardcoreCountAfter >= 10) give('hardcore_10');
  if (i.startedAt.hour < 6) give('early_bird');
  if (i.startedAt.hour >= 23 || i.startedAt.hour < 1) give('night_owl');
  if (i.todayMinutesBefore + i.actualMinutes >= 120) give('full_day');
  if (i.newLevel >= 5 && i.oldLevel < 5) give('level_5');
  if (i.newLevel >= 10 && i.oldLevel < 10) give('level_10');

  return out;
}

/// 세션 완료 XP.
int xpForSession({required int actualMinutes, required bool isHardcore}) {
  final double raw = actualMinutes * AppConstants.focusXpPerMinute;
  return (isHardcore ? raw * AppConstants.hardcoreXpMultiplier : raw).round();
}
