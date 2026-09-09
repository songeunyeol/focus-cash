import { onCall, HttpsError } from "firebase-functions/v2/https";
import { db, REGION, requireUid, requireString, ledgerEntry, Timestamp } from "./common";
import {
  Economy,
  applyDailyCap,
  computeStreak,
  dateKey,
  evaluateBadges,
  levelFromXp,
  sessionCredits,
  xpForSession,
} from "./rules";

/**
 * 집중 세션 정산 — 클라이언트의 FocusService.endSession + CreditService.addCredits 를 대체한다.
 *
 * 왜 서버인가:
 *  - 크레딧은 실물 기프티콘으로 바뀐다. 클라이언트가 계산한 숫자를 믿으면 안 된다.
 *  - 세션 문서의 startedAt 을 서버가 기록하고(서버 타임스탬프), 종료 시각도 서버가 찍으므로
 *    기기 시각 조작 감지 휴리스틱이 필요 없어진다.
 *  - 세션 id 로 멱등하다. 같은 세션을 두 번 정산할 수 없다 (settledAt 플래그).
 *
 * 입력: { sessionId }
 * 출력: { credits, firstFocusBonus, xpGained, badgeXpGained, oldLevel, newLevel, newBadges, currentStreak }
 */
export const settleSession = onCall({ region: REGION }, async (req) => {
  const uid = requireUid(req);
  const data = req.data as Record<string, unknown>;
  const sessionId = requireString(data.sessionId, "sessionId", 64);

  const sessionRef = db.collection("focus_sessions").doc(sessionId);
  const userRef = db.collection("users").doc(uid);

  return db.runTransaction(async (tx) => {
    const [sessionSnap, userSnap] = await Promise.all([tx.get(sessionRef), tx.get(userRef)]);
    if (!sessionSnap.exists) throw new HttpsError("not-found", "세션이 없습니다.");
    if (!userSnap.exists) throw new HttpsError("not-found", "사용자가 없습니다.");

    const s = sessionSnap.data()!;
    if (s.userId !== uid) throw new HttpsError("permission-denied", "본인 세션만 정산할 수 있습니다.");
    if (s.settledAt) throw new HttpsError("already-exists", "이미 정산된 세션입니다.");

    const startedAt: Date = (s.startedAt as Timestamp).toDate();
    const now = new Date();
    const targetMinutes = Number(s.targetMinutes);
    if (!Number.isInteger(targetMinutes) || targetMinutes < Economy.minFocusMinutes || targetMinutes > Economy.maxFocusMinutes) {
      throw new HttpsError("failed-precondition", "세션 목표 시간이 올바르지 않습니다.");
    }

    // 실제 경과는 서버 시각으로만 판단한다. 목표를 못 채웠으면 완료가 아니다.
    const elapsedMinutes = Math.floor((now.getTime() - startedAt.getTime()) / 60_000);
    if (elapsedMinutes < targetMinutes) {
      throw new HttpsError("failed-precondition", "목표 시간이 아직 지나지 않았습니다.");
    }
    const actualMinutes = targetMinutes;
    const hardcore = s.hardcoreMode === "hardcore";

    const u = userSnap.data()!;
    const todayKey = dateKey(now);

    // ── 크레딧 (일일 한도) ────────────────────────────────
    const base = sessionCredits(actualMinutes, hardcore ? "hardcore" : "normal", Boolean(s.watchedStartAd));
    const todayCreditsBefore = u.creditDate === todayKey ? Number(u.todayCredits ?? 0) : 0;
    const credits = applyDailyCap(todayCreditsBefore, base, Economy.dailyCreditCap);

    // ── 통계 · 스트릭 ───────────────────────────────────
    const totalBefore = Number(u.totalFocusMinutes ?? 0);
    const todayMinutesBefore = u.focusDate === todayKey ? Number(u.todayFocusMinutes ?? 0) : 0;
    const streak = computeStreak(
      todayKey,
      (u.lastFocusDate as string | undefined) ?? null,
      Number(u.currentStreak ?? 0),
      Number(u.longestStreak ?? 0),
    );

    // ── XP · 배지 ───────────────────────────────────────
    const xpBefore = Number(u.xp ?? 0);
    const oldLevel = Number(u.level ?? 1);
    const existingBadges: string[] = Array.isArray(u.badges) ? u.badges : [];
    const hardcoreAfter = Number(u.hardcoreSessionCount ?? 0) + (hardcore ? 1 : 0);
    const xpGained = xpForSession(actualMinutes, hardcore);
    const levelAfterXp = levelFromXp(xpBefore + xpGained);
    const startedLocalHour = new Date(startedAt.getTime() + 9 * 3_600_000).getUTCHours();
    const newBadges = evaluateBadges({
      totalMinutesBefore: totalBefore,
      actualMinutes,
      streakAfter: streak.currentStreak,
      hardcoreCountAfter: hardcoreAfter,
      todayMinutesBefore,
      startedAtHourLocal: startedLocalHour,
      oldLevel,
      newLevel: levelAfterXp,
      existingBadges,
    });
    const badgeXpGained = newBadges.length * Economy.badgeXp;
    const totalXp = xpBefore + xpGained + badgeXpGained;
    const newLevel = levelFromXp(totalXp);

    // ── 첫 집중 보너스 (구 가입 보너스) ─────────────────────
    const firstFocusBonus = totalBefore === 0 && !u.firstFocusBonusGiven ? Economy.firstFocusBonus : 0;

    const totalCreditsAfter = Number(u.totalCredits ?? 0) + credits + firstFocusBonus;

    tx.update(sessionRef, {
      actualMinutes,
      creditsEarned: credits,
      completed: true,
      endedAt: Timestamp.fromDate(now),
      settledAt: Timestamp.fromDate(now),
    });

    tx.update(userRef, {
      totalCredits: totalCreditsAfter,
      todayCredits: todayCreditsBefore + credits,
      creditDate: todayKey,
      totalFocusMinutes: totalBefore + actualMinutes,
      todayFocusMinutes: todayMinutesBefore + actualMinutes,
      focusDate: todayKey,
      lastActiveAt: now.toISOString(),
      currentStreak: streak.currentStreak,
      longestStreak: streak.longestStreak,
      lastFocusDate: todayKey,
      xp: totalXp,
      level: newLevel,
      ...(newBadges.length ? { badges: [...existingBadges, ...newBadges] } : {}),
      ...(hardcore ? { hardcoreSessionCount: hardcoreAfter } : {}),
      ...(firstFocusBonus ? { firstFocusBonusGiven: true } : {}),
    });

    if (credits > 0) {
      const desc = credits < base ? `${actualMinutes}분 집중 완료 (일일 한도 적용)` : `${actualMinutes}분 집중 완료`;
      const e = ledgerEntry(uid, credits, "earn", desc);
      tx.set(db.collection("credit_transactions").doc(e.id), e);
    }
    if (firstFocusBonus > 0) {
      const e = ledgerEntry(uid, firstFocusBonus, "earn", "첫 집중 완료 보너스");
      tx.set(db.collection("credit_transactions").doc(e.id), e);
    }

    return {
      credits,
      firstFocusBonus,
      xpGained,
      badgeXpGained,
      oldLevel,
      newLevel,
      newBadges,
      currentStreak: streak.currentStreak,
    };
  });
});

/**
 * 광고 보너스 — 클라이언트가 "봤다"고 말하는 것을 그대로 믿는다는 점에서 완전한 검증은 아니다.
 * AdMob SSV(Server-Side Verification) 콜백으로 옮기는 것이 다음 단계. 그래도 세션당 1회·일일 한도는 서버가 강제한다.
 * 입력: { sessionId, kind: "start" | "end" }
 */
export const grantAdBonus = onCall({ region: REGION }, async (req) => {
  const uid = requireUid(req);
  const data = req.data as Record<string, unknown>;
  const sessionId = requireString(data.sessionId, "sessionId", 64);
  const kind = data.kind === "start" || data.kind === "end" ? data.kind : null;
  if (!kind) throw new HttpsError("invalid-argument", "kind 는 start 또는 end 여야 합니다.");

  const sessionRef = db.collection("focus_sessions").doc(sessionId);
  const userRef = db.collection("users").doc(uid);

  return db.runTransaction(async (tx) => {
    const [sessionSnap, userSnap] = await Promise.all([tx.get(sessionRef), tx.get(userRef)]);
    if (!sessionSnap.exists || !userSnap.exists) throw new HttpsError("not-found", "대상이 없습니다.");
    const s = sessionSnap.data()!;
    if (s.userId !== uid) throw new HttpsError("permission-denied", "본인 세션이 아닙니다.");

    const flag = kind === "start" ? "startAdBonusGiven" : "endAdBonusGiven";
    if (s[flag]) throw new HttpsError("already-exists", "이미 지급된 보너스입니다.");
    if (kind === "end" && !s.settledAt) throw new HttpsError("failed-precondition", "정산 후에만 종료 보너스를 받을 수 있습니다.");

    const raw = kind === "start" ? Economy.startAdBonus : Math.round(Number(s.creditsEarned ?? 0) * Economy.endAdMultiplierRate);
    const u = userSnap.data()!;
    const todayKey = dateKey(new Date());
    const todayBefore = u.creditDate === todayKey ? Number(u.todayCredits ?? 0) : 0;
    const granted = applyDailyCap(todayBefore, raw, Economy.dailyCreditCap);

    tx.update(sessionRef, { [flag]: true, ...(kind === "start" ? { watchedStartAd: true } : { watchedEndAd: true }) });
    if (granted > 0) {
      tx.update(userRef, {
        totalCredits: Number(u.totalCredits ?? 0) + granted,
        todayCredits: todayBefore + granted,
        creditDate: todayKey,
      });
      const e = ledgerEntry(uid, granted, "earn", kind === "start" ? "시작 광고 시청 보너스" : "종료 광고 시청 보너스");
      tx.set(db.collection("credit_transactions").doc(e.id), e);
    }
    return { granted };
  });
});
