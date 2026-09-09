import { onCall, HttpsError } from "firebase-functions/v2/https";
import { auth, db, REGION, requireString } from "./common";

/**
 * 카카오 로그인 → Firebase custom token.
 *
 * 기존 방식은 `kakao_{id}@focuscash.app` / `FCS2024_K_{id}` 이메일·비밀번호를 클라이언트에서
 * 만들어 썼다. 카카오 ID 만 알면 누구나 그 계정으로 로그인할 수 있는 구조다.
 * 여기서는 카카오 액세스 토큰을 카카오 서버에 직접 검증하고, 검증된 ID 로만 토큰을 만든다.
 *
 * 마이그레이션: 기존 이메일 계정이 있으면 **그 uid 로** 토큰을 만들어 데이터가 유지되게 한다.
 * 신규는 `kakao:{id}` uid 를 쓴다.
 *
 * 입력: { accessToken }  출력: { token, isNewUser }
 */
export const kakaoSignIn = onCall({ region: REGION }, async (req) => {
  const accessToken = requireString((req.data as Record<string, unknown>).accessToken, "accessToken", 2048);

  const res = await fetch("https://kapi.kakao.com/v2/user/me", {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (!res.ok) throw new HttpsError("unauthenticated", "카카오 토큰 검증에 실패했습니다.");
  const me = (await res.json()) as { id?: number; kakao_account?: { profile?: { nickname?: string } } };
  if (!me.id) throw new HttpsError("unauthenticated", "카카오 사용자 정보를 확인할 수 없습니다.");

  const kakaoId = String(me.id);
  const nickname = me.kakao_account?.profile?.nickname ?? "카카오 유저";

  // 1) 구 이메일 계정이 있으면 그 uid 로 (데이터 보존)
  let uid: string;
  try {
    const legacy = await auth.getUserByEmail(`kakao_${kakaoId}@focuscash.app`);
    uid = legacy.uid;
  } catch {
    // 2) 없으면 provider 고정 uid
    uid = `kakao:${kakaoId}`;
    try {
      await auth.getUser(uid);
    } catch {
      await auth.createUser({ uid, displayName: nickname });
    }
  }

  const userDoc = await db.collection("users").doc(uid).get();
  const token = await auth.createCustomToken(uid, { provider: "kakao" });
  return { token, isNewUser: !userDoc.exists };
});
