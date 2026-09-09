/**
 * 관리자 custom claim 부여 — 로컬에서 한 번 실행한다.
 *
 *   GOOGLE_APPLICATION_CREDENTIALS=./service-account.json npm run set-admin -- <uid>
 *
 * 관리자 앱은 이 claim 이 있는 계정으로 Google 로그인하고, Firestore 규칙은
 * `request.auth.token.admin == true` 만 관리자 쓰기를 허용한다.
 * "익명 로그인 = 관리자" 였던 규칙은 누구나 관리자가 될 수 있었다.
 */
import { initializeApp, applicationDefault } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";

async function main() {
  const uid = process.argv[2];
  const revoke = process.argv.includes("--revoke");
  if (!uid) {
    console.error("usage: set-admin <uid> [--revoke]");
    process.exit(1);
  }
  initializeApp({ credential: applicationDefault() });
  const auth = getAuth();
  const user = await auth.getUser(uid);
  await auth.setCustomUserClaims(uid, { ...(user.customClaims ?? {}), admin: !revoke });
  console.log(`${revoke ? "revoked" : "granted"} admin for ${uid} (${user.email ?? user.displayName ?? ""})`);
  console.log("적용은 다음 ID 토큰 갱신(최대 1시간) 또는 재로그인 후.");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
