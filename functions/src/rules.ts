/**
 * 크레딧 경제 규칙 — lib/domain/*.dart 와 1:1 대응.
 *
 * 숫자를 바꾸면 양쪽을 같이 바꿔야 한다. 클라이언트는 "예상치"를 보여주기 위해,
 * 서버는 "실제 지급"을 위해 같은 규칙을 쓴다. 서버 값이 항상 진실이다.
 *
 * 두 구현이 같은 답을 내는지는 `test/fixtures/economy_rules.json` 하나를
 * Dart(`test/domain/economy_parity_test.dart`)와 TS(`src/parity.test.ts`)가 같이 읽어 검사한다.
 * 케이스를 추가할 때도 그 파일에만 넣으면 된다.
 */

export const Economy = {
  creditsPerTenMinutes: 10,
  startAdBonus: 15,
  endAdMultiplierRate: 0.2,
  hardcoreBonusRate: 1.2,
  hardcorePenaltyRate: 0.1,
  dailyCreditCap: 250,
  firstFocusBonus: 200,
  referralBonus: 200,
  minFocusMinutes: 10,
  maxFocusMinutes: 120,
  focusXpPerMinute: 1,
  hardcoreXpMultiplier: 1.2,
  badgeXp: 50,
  checkInXp: 10,
  rouletteCost: 50,
  rouletteDailyLimit: 3,
  /** 룰렛 기프티콘 재고가 방금 소진됐을 때 대체 지급 (클라이언트 정책과 동일) */
  rouletteStockFallbackCredits: 100,
  /** invite_3 배지 기준 */
  inviteBadgeCount: 3,
} as const;

export type HardcoreMode = "normal" | "hardcore";

export function sessionCredits(
  focusMinutes: number,
  hardcoreMode: HardcoreMode = "normal",
  watchedStartAd = false,
): number {
  const blocks = Math.floor(focusMinutes / 10);
  let base = blocks * Economy.creditsPerTenMinutes;
  if (hardcoreMode === "hardcore") base = Math.round(base * Economy.hardcoreBonusRate);
  if (watchedStartAd) base += Economy.startAdBonus;
  return base;
}

export function endAdBonus(earned: number): number {
  return Math.round(earned * Economy.endAdMultiplierRate);
}

export function applyDailyCap(todayCredits: number, amount: number, cap: number | null): number {
  if (cap === null) return amount;
  const room = cap - todayCredits;
  if (room <= 0) return 0;
  return Math.min(amount, room);
}

/** 하드코어 포기 페널티. 보유 잔액 비례, 0 이상. */
export function hardcorePenalty(totalCredits: number): number {
  const p = Math.round(totalCredits * Economy.hardcorePenaltyRate);
  return p > 0 ? p : 0;
}

export function xpForSession(actualMinutes: number, isHardcore: boolean): number {
  const raw = actualMinutes * Economy.focusXpPerMinute;
  return Math.round(isHardcore ? raw * Economy.hardcoreXpMultiplier : raw);
}

// ── 레벨 (AppConstants.xpForLevel / levelFromXp) ─────────────────────────
export function xpForLevel(level: number): number {
  if (level <= 1) return 0;
  if (level <= 5) return (level - 1) * 125;
  if (level <= 10) return 500 + (level - 5) * 200;
  if (level <= 20) return 1500 + (level - 10) * 250;
  if (level <= 30) return 4000 + (level - 20) * 400;
  if (level <= 50) return 8000 + (level - 30) * 600;
  return 20000 + (level - 50) * 1000;
}

export function levelFromXp(xp: number): number {
  let lv = 1;
  while (xpForLevel(lv + 1) <= xp) lv++;
  return lv;
}

// ── 스트릭 (streak_rules.dart) ────────────────────────────────────────────
export function dateKey(d: Date, tzOffsetMinutes = 540): string {
  // Firestore 는 UTC. 한국 사용자 기준 하루 경계(KST, +540분)로 키를 만든다.
  const local = new Date(d.getTime() + tzOffsetMinutes * 60_000);
  return local.toISOString().slice(0, 10);
}

export interface StreakResult {
  currentStreak: number;
  longestStreak: number;
  counted: boolean;
}

export function computeStreak(
  todayKey: string,
  lastFocusKey: string | null,
  currentStreak: number,
  longestStreak: number,
): StreakResult {
  if (lastFocusKey === todayKey) {
    return { currentStreak, longestStreak, counted: false };
  }
  const today = new Date(`${todayKey}T00:00:00Z`);
  const yesterday = new Date(today.getTime() - 86_400_000).toISOString().slice(0, 10);
  const next = lastFocusKey === yesterday ? currentStreak + 1 : 1;
  return {
    currentStreak: next,
    longestStreak: Math.max(next, longestStreak),
    counted: true,
  };
}

// ── 배지 (badge_rules.dart) ───────────────────────────────────────────────
export interface BadgeInput {
  totalMinutesBefore: number;
  actualMinutes: number;
  streakAfter: number;
  hardcoreCountAfter: number;
  todayMinutesBefore: number;
  startedAtHourLocal: number;
  oldLevel: number;
  newLevel: number;
  existingBadges: string[];
}

export function evaluateBadges(i: BadgeInput): string[] {
  const out: string[] = [];
  const give = (id: string) => {
    if (!i.existingBadges.includes(id) && !out.includes(id)) out.push(id);
  };
  const totalAfter = i.totalMinutesBefore + i.actualMinutes;
  if (i.totalMinutesBefore === 0) give("first_focus");
  if (totalAfter >= 600) give("focus_10h");
  if (totalAfter >= 6000) give("focus_100h");
  if (i.streakAfter >= 7) give("streak_7");
  if (i.streakAfter >= 30) give("streak_30");
  if (i.hardcoreCountAfter >= 10) give("hardcore_10");
  if (i.startedAtHourLocal < 6) give("early_bird");
  if (i.startedAtHourLocal >= 23 || i.startedAtHourLocal < 1) give("night_owl");
  if (i.todayMinutesBefore + i.actualMinutes >= 120) give("full_day");
  if (i.newLevel >= 5 && i.oldLevel < 5) give("level_5");
  if (i.newLevel >= 10 && i.oldLevel < 10) give("level_10");
  return out;
}

// ── 가중 추첨 (weighted_pick.dart) ────────────────────────────────────────
export function pickWeightedIndex(weights: number[], roll: number): number | null {
  if (roll < 0) return null;
  let cumulative = 0;
  for (let i = 0; i < weights.length; i++) {
    cumulative += weights[i];
    if (roll < cumulative) return i;
  }
  return null;
}

// ── 앱 버전 게이트 (version_gate.dart) ───────────────────────────────────
export type UpdateRequirement = "none" | "recommended" | "required";

/**
 * 규칙 v2 배포 뒤 구버전 앱은 정산이 permission-denied 로 실패한다.
 * `app_config/android` 문서의 minBuildNumber 미만이면 강제 업데이트, latestBuildNumber 미만이면 권장.
 */
export function evaluateVersionGate(
  currentBuild: number,
  minBuild: number,
  latestBuild: number,
): UpdateRequirement {
  if (currentBuild < minBuild) return "required";
  if (currentBuild < latestBuild) return "recommended";
  return "none";
}
