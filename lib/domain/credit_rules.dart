import '../config/constants.dart';

/// 크레딧 경제의 순수 계산 규칙.
///
/// Firestore 를 모르는 함수만 둔다. 서비스와 화면은 여기 결과를 쓰기만 하고,
/// 숫자를 바꿀 때는 [AppConstants] 와 이 파일의 테스트만 보면 된다.
abstract final class CreditRules {
  /// 세션 완료 크레딧. 10분 블록 단위로 계산하고 잔여분은 버린다.
  static int sessionCredits({
    required int focusMinutes,
    String hardcoreMode = 'normal',
    bool watchedStartAd = false,
  }) {
    final int blocks = focusMinutes ~/ 10;
    int base = blocks * AppConstants.creditsPerTenMinutes;
    if (hardcoreMode == 'hardcore') {
      base = (base * AppConstants.hardcoreBonusRate).round();
    }
    if (watchedStartAd) base += AppConstants.startAdBonus;
    return base;
  }

  /// 종료 리워드 광고 보너스 — 획득 크레딧에 비례한다.
  static int endAdBonus(int earnedCredits) =>
      (earnedCredits * AppConstants.endAdMultiplierRate).round();

  /// 일일 적립 한도를 적용한 실제 지급량. 항상 0 이상이다.
  /// [cap] 이 null 이면 제한하지 않는다.
  static int applyDailyCap({
    required int todayCredits,
    required int amount,
    required int? cap,
  }) {
    if (cap == null) return amount;
    final int room = cap - todayCredits;
    if (room <= 0) return 0;
    return amount > room ? room : amount;
  }

  /// 하드코어 포기 페널티. 현행 정책은 보유 잔액 비례다.
  static int hardcorePenalty({required int totalCredits}) =>
      (totalCredits * AppConstants.hardcorePenaltyRate).round();
}
