import { test } from "node:test";
import assert from "node:assert/strict";
import {
  applyDailyCap,
  computeStreak,
  evaluateBadges,
  levelFromXp,
  pickWeightedIndex,
  sessionCredits,
  xpForLevel,
} from "./rules";

test("sessionCredits: 10분 블록, 하드코어 1.2배, 시작광고 +15", () => {
  assert.equal(sessionCredits(59), 50);
  assert.equal(sessionCredits(50, "hardcore"), 60);
  assert.equal(sessionCredits(30, "normal", true), 45);
});

test("applyDailyCap: 한도 초과분은 잘리고 음수는 없다", () => {
  assert.equal(applyDailyCap(220, 60, 250), 30);
  assert.equal(applyDailyCap(300, 60, 250), 0);
  assert.equal(applyDailyCap(9999, 60, null), 60);
});

test("levelFromXp 는 xpForLevel 의 역함수", () => {
  for (let lv = 1; lv <= 55; lv++) {
    assert.equal(levelFromXp(xpForLevel(lv)), lv);
  }
});

test("computeStreak: 어제→+1, 건너뜀→1, 오늘 이미→변화 없음", () => {
  assert.equal(computeStreak("2026-09-09", "2026-09-08", 4, 10).currentStreak, 5);
  assert.equal(computeStreak("2026-09-09", "2026-09-07", 4, 4).currentStreak, 1);
  assert.equal(computeStreak("2026-09-09", "2026-09-09", 4, 4).counted, false);
  assert.equal(computeStreak("2026-10-01", "2026-09-30", 1, 1).currentStreak, 2);
});

test("evaluateBadges: first_focus 는 누적 0분일 때만, 기존 배지는 제외", () => {
  const base = {
    totalMinutesBefore: 0,
    actualMinutes: 30,
    streakAfter: 7,
    hardcoreCountAfter: 0,
    todayMinutesBefore: 0,
    startedAtHourLocal: 14,
    oldLevel: 1,
    newLevel: 1,
    existingBadges: ["streak_7"],
  };
  const r = evaluateBadges(base);
  assert.ok(r.includes("first_focus"));
  assert.ok(!r.includes("streak_7"));
  assert.equal(new Set(r).size, r.length);
});

test("pickWeightedIndex: 구간 경계", () => {
  const w = [55, 25, 10, 6, 3, 1];
  assert.equal(pickWeightedIndex(w, 0), 0);
  assert.equal(pickWeightedIndex(w, 54), 0);
  assert.equal(pickWeightedIndex(w, 55), 1);
  assert.equal(pickWeightedIndex(w, 99), 5);
  assert.equal(pickWeightedIndex(w, 100), null);
});
