/**
 * Focus Cash Cloud Functions (asia-northeast3)
 *
 * 원칙: 크레딧 잔액을 바꾸는 코드는 여기에만 있다. 클라이언트는 요청하고 결과를 보여준다.
 * 각 함수의 목적과 입력/출력은 파일 상단 주석에 있다. 배포 순서는 docs/SERVER_MIGRATION.md.
 *
 * 함수 목록 (9개)
 *  - settleSession / abandonSession / grantAdBonus  … 세션 정산·포기·광고 보너스
 *  - redeemGifticon / spinRoulette / enterRaffle     … 상점
 *  - kakaoSignIn                                     … 카카오 토큰 → custom token
 *  - onUserDeleted / onDeliverySubmitted             … 트리거
 */
export { settleSession, abandonSession, grantAdBonus } from "./settleSession";
export { redeemGifticon, spinRoulette, enterRaffle } from "./store";
export { kakaoSignIn } from "./kakaoSignIn";
export { onUserDeleted, onDeliverySubmitted } from "./lifecycle";
