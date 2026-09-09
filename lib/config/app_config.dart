/// 배포 단계별 스위치.
///
/// 서버(Cloud Functions)가 배포되기 전까지는 전부 false 다. 순서는 docs/SERVER_MIGRATION.md.
/// 컴파일 타임 상수로 두는 이유: 잘못된 조합으로 배포되는 사고를 막기 위해서다 —
/// 원격 플래그로 켰다가 함수가 없으면 모든 정산이 실패한다.
abstract final class AppConfig {
  /// 세션 정산·광고 보너스를 서버 callable(settleSession / grantAdBonus)로 처리한다.
  /// false 면 기존처럼 클라이언트가 Firestore 트랜잭션으로 직접 지급한다.
  static const bool useServerSettlement = false;

  /// 상점(교환·룰렛·응모)을 서버 callable 로 처리한다. (다음 이행 단계)
  static const bool useServerStore = false;

  /// 카카오 로그인을 서버 custom token 경로로 처리한다.
  static const bool useServerKakaoAuth = false;
}
