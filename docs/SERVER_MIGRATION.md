# 서버 이관 계획 — 크레딧을 클라이언트 밖으로

> 19차 세션(2026-09-09) 리뷰에서 확정. 이 문서는 **왜**와 **순서**를 남긴다.
> 코드는 `functions/`, 규칙은 `firestore.rules.next`, 클라이언트 스위치는 `lib/services/server_api.dart`.

## 왜 지금인가

Focus Cash 는 크레딧이 실물 기프티콘으로 바뀌는 앱이다. 그런데 v1 구조에서는 아래가 전부 **본인 ID 토큰 + REST 한 줄**로 가능했다 (`firestore.rules` v1 기준):

| # | 구멍 | 근거 |
|---|---|---|
| S1 | 크레딧 자가 발급 | `users/{uid}` update 가 본인이면 모든 필드 허용 |
| S2 | 미사용 기프티콘 코드 전체 열람 | `gifticon_codes` read 가 인증 유저 전체 |
| S3 | 기프티콘 무단 점유 | `gifticon_codes` update 가 인증 유저 전체 |
| S4 | 누구나 관리자 | 관리자 = `sign_in_provider == 'anonymous'`, 익명 인증이 켜져 있음 |
| S5 | 카카오 계정 탈취 | 비밀번호가 `FCS2024_K_{kakaoId}` 로 결정적 |
| S6 | 응모 티켓 위조 | `raffle_entries` create 가 userId 만 검사 |
| S7 | 시크릿 노출 | 카카오 키(Manifest), 키스토어 비번(gradle) 커밋 / 텔레그램 토큰 APK 포함 |

디자인 이행보다 이게 먼저다. 출시 후 첫 달 안에 터지는 종류의 문제다.

## 목표 구조

```
클라이언트                      Cloud Functions (asia-northeast3)          Firestore
─────────                      ─────────────────────────────────          ─────────
세션 시작 (문서 생성) ───────────────────────────────────────────────▶ focus_sessions (startedAt = 서버시각)
타이머 표시 (예상치)
목표 도달 → settleSession ────▶ 서버시각으로 경과 검증, 크레딧·XP·스트릭·배지·초대보너스 ─▶ users / credit_transactions
포기     → abandonSession ────▶ 포기 표시 + 하드코어 페널티                  ─▶ focus_sessions / users
광고 시청 → grantAdBonus ─────▶ 세션당 1회, 일일 한도                        ─▶ users / credit_transactions
교환     → redeemGifticon ────▶ 잔액+차감+발급 한 트랜잭션                    ─▶ users / gifticon_codes
룰렛     → spinRoulette ──────▶ 서버 난수, 일일 한도                          ─▶ users / gifticon_codes
응모     → enterRaffle ───────▶ 차감+티켓+마감 시 서버 추첨                   ─▶ users / raffle_*
카카오   → kakaoSignIn ───────▶ 카카오 토큰 검증 → custom token
(자동)   onUserDeleted ────────▶ 개인정보 정리
(자동)   onDeliverySubmitted ──▶ 텔레그램 알림 (토큰은 Secret Manager)
```

클라이언트에는 **잔액을 바꾸는 코드가 남지 않는다.** `lib/domain/*` 은 "예상 크레딧" 표시용으로만 남고, 서버 `functions/src/rules.ts` 가 같은 규칙의 진실이다. 숫자를 바꿀 때는 둘을 함께 바꾼다 (양쪽에 테스트가 있다).

## 배포 순서 (되돌릴 수 있게)

### 0. 사전 확인 (5분)
- [ ] Firebase 콘솔 → Firestore → 규칙 탭에서 **현재 배포된 규칙**을 복사해 `firestore.rules.deployed-backup` 으로 저장. 레포의 v1 규칙과 다를 가능성이 높다 (레포 규칙대로면 응모·룰렛 기록이 permission-denied 여야 하는데 동작했으므로).
- [ ] Blaze 플랜 전환 (Functions 필요). 무료 할당: 월 200만 호출.
- [ ] `firebase login` 후 `firebase use focuscash-2676f`

### 1. 시크릿 회전 (노출된 것들)
- [ ] 카카오 개발자 콘솔 → 네이티브 앱 키 재발급 → `secrets.dart` + `AndroidManifest.xml` scheme 교체
- [ ] 텔레그램 `@BotFather` → `/revoke` 후 새 토큰 → `firebase functions:secrets:set TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`
- [ ] 키스토어: 비밀번호는 이미 `android/key.properties`(gitignore) 로 이동. jks 자체는 유출되지 않았으므로 회전 불필요. **git 히스토리에는 남아 있다** — 레포가 public 이므로 `git filter-repo` 로 지우거나, 최소한 Play App Signing 이 켜져 있는지 확인.

### 2. Functions 배포
```bash
cd functions && npm install && npm test
firebase deploy --only functions
```
- [ ] 콘솔에서 9개 함수 확인: settleSession, abandonSession, grantAdBonus, redeemGifticon, spinRoulette, enterRaffle, kakaoSignIn, onUserDeleted, onDeliverySubmitted
- [ ] 관리자 claim: 본인 Google 계정으로 앱에 로그인해 uid 확보 →
  `GOOGLE_APPLICATION_CREDENTIALS=service-account.json npm run set-admin -- <uid>`

### 3. 클라이언트 스위치 켜기
스위치는 두 개다 (`lib/config/app_config.dart`). **카카오 로그인은 스위치가 없다** — 구 이메일+고정 비밀번호
경로는 제거했고 항상 서버(`kakaoSignIn`)를 탄다. 즉 2단계(Functions 배포) 전에는 카카오 로그인이 동작하지 않는다.
- [ ] `useServerSettlement = true` → 정산·포기(하드코어 페널티)·광고 보너스·**친구 초대 보너스**가 callable 로 간다.
      클라이언트의 시각 조작 감지(`_detectClockJump`)는 이 모드에서 자동으로 꺼진다 (서버 시각이 기준).
- [ ] `useServerStore = true` → 교환·룰렛·응모 + 직접배송 텔레그램 알림(서버 트리거)이 서버로 간다.
- [ ] 둘 다 켜지면 `AppConfig.clientBalanceWritesAllowed == false` 가 되고, `CreditService` 의 쓰기 메서드는
      호출되는 즉시 `StateError` 를 던진다. 남은 호출처가 있으면 여기서 드러난다.
- [ ] 관리자 앱: PIN → Google 로그인 + claim 확인 (`focus_cash_admin/lib/screens/login_screen.dart`, 19차에 적용)
- [ ] 내부 테스트 트랙에 배포, 완주 1회 → `credit_transactions.source == 'server'` 확인.
      원장 `createdAt` 은 클라이언트와 같은 문자열 형식(KST, 오프셋 없음)이고 `createdAtTs` 가 서버 Timestamp 다 —
      정렬 호환을 위해 일부러 그렇게 둔다 (`functions/src/common.ts` `isoLocal`).

### 4. 규칙 교체 + 최소 버전 올리기 (마지막, 되돌리기 쉬움)
```bash
cp firestore.rules firestore.rules.v1-backup
cp firestore.rules.next firestore.rules
firebase deploy --only firestore:rules
```
- [ ] 구버전 앱은 이 시점부터 정산·교환이 permission-denied 로 실패한다. 앱은 시작 시 `app_config/android` 를 읽어
      `minBuildNumber` 미만이면 **강제 업데이트 화면**(`UpdateRequiredScreen`)을 띄운다. 규칙 배포 직후 콘솔에서 이 문서를 만든다:
      ```
      app_config/android { minBuildNumber: <서버 스위치가 켜진 첫 빌드>, latestBuildNumber: <최신 빌드>, storeUrl?: "...", message?: "..." }
      ```
      문서가 없거나 읽기에 실패하면 아무도 막지 않는다 (오프라인 사용자 보호). 판정 규칙은 `lib/domain/version_gate.dart` = `rules.ts evaluateVersionGate`.
- [ ] 문제가 생기면 `firestore.rules.v1-backup` 으로 즉시 롤백하고 `minBuildNumber` 를 0 으로 내린다.

### 5. 뒷정리
- [ ] Firebase 콘솔 → Authentication → 익명 로그인 **비활성화**
- [ ] `lib/services/telegram_service.dart` 삭제, `AppSecrets.telegramBotToken` 제거 (이미 `useServerStore` 면 호출 안 됨)
- [ ] 클라이언트 `CreditService.addCredits/spendCredits/applyPenalty` 와 `_assertClientWritesAllowed` 삭제,
      `FocusProvider._maybeGiveReferralBonus`·`_maybeGiveFirstFocusBonus`, `StoreService` 의 발급·응모·룰렛 횟수 메서드,
      `XpService.onInviteSuccess` 삭제 (전부 서버가 한다)
- [ ] `FocusProvider` 의 시각 조작 감지(`_detectClockJump`)·`_monotonic` 제거 — 서버 시각이 앵커다
- [ ] Firestore 인덱스: `gifticon_codes(usedBy ASC, isUsed ASC, usedAt DESC)` 추가 (규칙 v2 의 read 조건에 맞춘 쿼리)
- [ ] `test/fixtures/economy_rules.json` 은 남긴다. 숫자를 바꿀 때 Dart·TS 양쪽 패리티 테스트가 이 파일을 읽는다.

## 규칙 v2 가 막는 것 / 허용하는 것

| 컬렉션 | 클라이언트 읽기 | 클라이언트 쓰기 |
|---|---|---|
| users | 인증 유저 | 본인: displayName·avatarIndex·marketingAgreed·lastActiveAt·lastCheckInDate·inviteCode 만 |
| focus_sessions | 인증 유저 | 본인: 생성(미완료, startedAt=서버시각), 포기 표시만 |
| credit_transactions | 본인 것 | ✗ |
| gifticon_codes | **내가 발급받은 것만** | 직접배송 당첨자: 배송지 필드만 |
| store_items / raffle_rooms / roulette_config | 인증 유저 | 관리자 claim 만 |
| raffle_entries | 인증 유저 | ✗ (서버만) |
| friend_requests | 당사자 | 생성(pending)·수락/거절(받은 사람)·삭제(당사자) |
| user_notes | 본인 | 본인 |
| app_config | **누구나** (로그인 전 버전 확인) | 관리자 claim 만 |

## 이후 (서버가 있으면 열리는 것)
- `daily_stats/{uid}_{date}` 집계 → 랭킹 풀 스캔 제거 (현재 월간 랭킹 1회 = 기간 내 세션 전체 읽기)
- AdMob SSV(Server-Side Verification) → 광고 보너스도 서버가 검증
- 운영 대시보드: 일별 발행/소각 크레딧, 미사용 코드 재고 (관리자 앱)
- 크레딧 만료 정책 (장기 미사용 잔액 = 부채)
