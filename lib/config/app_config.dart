/// 배포 단계별 스위치.
///
/// 서버(Cloud Functions)가 배포되기 전까지는 전부 false 다. 순서는 docs/SERVER_MIGRATION.md.
/// 컴파일 타임 상수로 두는 이유: 잘못된 조합으로 배포되는 사고를 막기 위해서다 —
/// 원격 플래그로 켰다가 함수가 없으면 모든 정산이 실패한다.
///
/// 카카오 로그인은 스위치가 없다. 구 이메일+고정 비밀번호 경로는 카카오 ID 만 알면 타인 계정에
/// 들어갈 수 있는 구조라 제거했고, 항상 서버(kakaoSignIn)를 탄다. 즉 **카카오 로그인은
/// Functions 배포 뒤부터 동작한다** (구글 로그인은 영향 없음).
abstract final class AppConfig {
  /// 세션 정산·포기·광고 보너스를 서버 callable(settleSession / abandonSession / grantAdBonus)로 처리한다.
  /// false 면 기존처럼 클라이언트가 Firestore 트랜잭션으로 직접 지급한다.
  /// 친구 초대 보너스도 이 스위치를 따른다 (서버 정산이 피초대자 첫 완료 시 함께 지급).
  static const bool useServerSettlement = false;

  /// 상점(교환·룰렛·응모)을 서버 callable 로 처리한다.
  /// 직접배송 텔레그램 알림도 이 스위치를 따른다 (서버 트리거 onDeliverySubmitted).
  static const bool useServerStore = false;

  /// 클라이언트가 users.totalCredits 를 직접 쓸 수 있는 단계인지.
  ///
  /// 두 스위치가 모두 켜지면 잔액을 바꾸는 클라이언트 코드는 호출될 일이 없어야 하고,
  /// [CreditService] 의 쓰기 메서드는 이 값이 false 일 때 [StateError] 를 던진다.
  /// 규칙 v2 가 배포되면 어차피 permission-denied 지만, 그 전에 코드 경로에서 잡는 것이 목적이다.
  static const bool clientBalanceWritesAllowed =
      !(useServerSettlement && useServerStore);

  /// 앱 시작 시 `app_config/android` 문서의 최소 빌드 번호를 확인한다.
  /// 규칙 v2 배포 뒤 구버전 앱을 막는 용도. 문서가 없으면 아무도 막지 않는다.
  static const bool checkMinimumVersion = true;

  /// 강제 업데이트 화면의 기본 스토어 링크. `app_config/android.storeUrl` 이 있으면 그것이 우선.
  static const String defaultStoreUrl =
      'https://play.google.com/store/apps/details?id=com.focuscash.focus_cash';
}
