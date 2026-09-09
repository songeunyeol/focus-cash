/**
 * 서버 규칙 ↔ 클라이언트 규칙 동기화 테스트.
 *
 * `test/fixtures/economy_rules.json` 을 Dart 테스트(test/domain/economy_parity_test.dart)와
 * 함께 읽는다. 여기서 실패하면 숫자가 양쪽에서 갈라진 것이다.
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import {
  Economy,
  applyDailyCap,
  computeStreak,
  endAdBonus,
  evaluateBadges,
  evaluateVersionGate,
  hardcorePenalty,
  levelFromXp,
  pickWeightedIndex,
  sessionCredits,
  xpForLevel,
  xpForSession,
} from "./rules";

// 컴파일 결과는 functions/lib/ 에 놓이므로 저장소 루트는 두 단계 위다.
const fixturePath = join(__dirname, "..", "..", "test", "fixtures", "economy_rules.json");
const fx = JSON.parse(readFileSync(fixturePath, "utf8"));

test("parity: 상수", () => {
  for (const [k, v] of Object.entries(fx.constants as Record<string, number>)) {
    assert.equal((Economy as Record<string, number>)[k], v, `Economy.${k}`);
  }
});

test("parity: sessionCredits", () => {
  for (const c of fx.sessionCredits) {
    assert.equal(sessionCredits(c.minutes, c.mode, c.startAd), c.expected, JSON.stringify(c));
  }
});

test("parity: endAdBonus", () => {
  for (const c of fx.endAdBonus) assert.equal(endAdBonus(c.earned), c.expected, JSON.stringify(c));
});

test("parity: applyDailyCap", () => {
  for (const c of fx.dailyCap) assert.equal(applyDailyCap(c.today, c.amount, c.cap), c.expected, JSON.stringify(c));
});

test("parity: hardcorePenalty", () => {
  for (const c of fx.hardcorePenalty) assert.equal(hardcorePenalty(c.total), c.expected, JSON.stringify(c));
});

test("parity: xpForSession", () => {
  for (const c of fx.xpForSession) assert.equal(xpForSession(c.minutes, c.hardcore), c.expected, JSON.stringify(c));
});

test("parity: 레벨 테이블", () => {
  for (const c of fx.levelTable) {
    assert.equal(xpForLevel(c.level), c.xp, `xpForLevel(${c.level})`);
    assert.equal(levelFromXp(c.xp), c.level, `levelFromXp(${c.xp})`);
    if (c.xp > 0) assert.equal(levelFromXp(c.xp - 1), c.level - 1, `levelFromXp(${c.xp - 1})`);
  }
});

test("parity: computeStreak", () => {
  for (const c of fx.streak) {
    const r = computeStreak(c.today, c.last, c.current, c.longest);
    assert.equal(r.currentStreak, c.expectedCurrent, JSON.stringify(c));
    assert.equal(r.longestStreak, c.expectedLongest, JSON.stringify(c));
    assert.equal(r.counted, c.counted, JSON.stringify(c));
  }
});

test("parity: evaluateBadges", () => {
  for (const c of fx.badges) {
    assert.deepEqual([...evaluateBadges(c.input)].sort(), [...c.expected].sort(), c.name);
  }
});

test("parity: pickWeightedIndex", () => {
  for (const c of fx.weightedPick) assert.equal(pickWeightedIndex(c.weights, c.roll), c.expected, JSON.stringify(c));
});

test("parity: evaluateVersionGate", () => {
  for (const c of fx.versionGate) assert.equal(evaluateVersionGate(c.current, c.min, c.latest), c.expected, JSON.stringify(c));
});
