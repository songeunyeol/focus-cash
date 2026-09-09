import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_cash/config/constants.dart';
import 'package:focus_cash/domain/badge_rules.dart';
import 'package:focus_cash/domain/credit_rules.dart';
import 'package:focus_cash/domain/streak_rules.dart';
import 'package:focus_cash/domain/version_gate.dart';
import 'package:focus_cash/domain/weighted_pick.dart';

/// 서버(functions/src/rules.ts)와 같은 픽스처를 읽는다.
/// 여기서 실패하면 클라이언트 "예상치"와 서버 "실제 지급"이 갈라진 것이다.
Map<String, dynamic> _loadFixture() {
  final file = File('test/fixtures/economy_rules.json');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  final fx = _loadFixture();

  group('parity: 상수', () {
    final c = fx['constants'] as Map<String, dynamic>;
    test('AppConstants 가 픽스처와 같다', () {
      expect(AppConstants.creditsPerTenMinutes, c['creditsPerTenMinutes']);
      expect(AppConstants.startAdBonus, c['startAdBonus']);
      expect(AppConstants.endAdMultiplierRate, c['endAdMultiplierRate']);
      expect(AppConstants.hardcoreBonusRate, c['hardcoreBonusRate']);
      expect(AppConstants.hardcorePenaltyRate, c['hardcorePenaltyRate']);
      expect(AppConstants.dailyCreditCap, c['dailyCreditCap']);
      expect(AppConstants.firstFocusBonus, c['firstFocusBonus']);
      expect(AppConstants.referralBonus, c['referralBonus']);
      expect(AppConstants.minFocusMinutes, c['minFocusMinutes']);
      expect(AppConstants.maxFocusMinutes, c['maxFocusMinutes']);
      expect(AppConstants.focusXpPerMinute, c['focusXpPerMinute']);
      expect(AppConstants.hardcoreXpMultiplier, c['hardcoreXpMultiplier']);
      expect(AppConstants.badgeXp, c['badgeXp']);
      expect(AppConstants.checkInXp, c['checkInXp']);
      expect(AppConstants.rouletteCost, c['rouletteCost']);
      expect(AppConstants.rouletteDailyLimit, c['rouletteDailyLimit']);
    });
  });

  test('parity: sessionCredits', () {
    for (final c in fx['sessionCredits'] as List) {
      expect(
        CreditRules.sessionCredits(
          focusMinutes: c['minutes'] as int,
          hardcoreMode: c['mode'] as String,
          watchedStartAd: c['startAd'] as bool,
        ),
        c['expected'],
        reason: '$c',
      );
    }
  });

  test('parity: endAdBonus', () {
    for (final c in fx['endAdBonus'] as List) {
      expect(CreditRules.endAdBonus(c['earned'] as int), c['expected'],
          reason: '$c');
    }
  });

  test('parity: applyDailyCap', () {
    for (final c in fx['dailyCap'] as List) {
      expect(
        CreditRules.applyDailyCap(
          todayCredits: c['today'] as int,
          amount: c['amount'] as int,
          cap: c['cap'] as int?,
        ),
        c['expected'],
        reason: '$c',
      );
    }
  });

  test('parity: hardcorePenalty', () {
    for (final c in fx['hardcorePenalty'] as List) {
      expect(CreditRules.hardcorePenalty(totalCredits: c['total'] as int),
          c['expected'],
          reason: '$c');
    }
  });

  test('parity: xpForSession', () {
    for (final c in fx['xpForSession'] as List) {
      expect(
        xpForSession(
            actualMinutes: c['minutes'] as int,
            isHardcore: c['hardcore'] as bool),
        c['expected'],
        reason: '$c',
      );
    }
  });

  test('parity: 레벨 테이블', () {
    for (final c in fx['levelTable'] as List) {
      final level = c['level'] as int;
      final xp = c['xp'] as int;
      expect(AppConstants.xpForLevel(level), xp, reason: 'xpForLevel($level)');
      expect(AppConstants.levelFromXp(xp), level, reason: 'levelFromXp($xp)');
      if (xp > 0) {
        expect(AppConstants.levelFromXp(xp - 1), level - 1,
            reason: 'levelFromXp(${xp - 1})');
      }
    }
  });

  test('parity: computeStreak', () {
    for (final c in fx['streak'] as List) {
      final r = computeStreak(
        today: DateTime.parse(c['today'] as String),
        lastFocusDate:
            c['last'] == null ? null : DateTime.parse(c['last'] as String),
        currentStreak: c['current'] as int,
        longestStreak: c['longest'] as int,
      );
      expect(r.currentStreak, c['expectedCurrent'], reason: '$c');
      expect(r.longestStreak, c['expectedLongest'], reason: '$c');
      expect(r.counted, c['counted'], reason: '$c');
    }
  });

  test('parity: evaluateBadges', () {
    for (final c in fx['badges'] as List) {
      final i = c['input'] as Map<String, dynamic>;
      final result = evaluateBadges(BadgeInput(
        totalMinutesBefore: i['totalMinutesBefore'] as int,
        actualMinutes: i['actualMinutes'] as int,
        streakAfter: i['streakAfter'] as int,
        hardcoreCountAfter: i['hardcoreCountAfter'] as int,
        todayMinutesBefore: i['todayMinutesBefore'] as int,
        // 서버는 KST 시(hour)만 넘긴다. 같은 시로 DateTime 을 만든다.
        startedAt: DateTime(2026, 9, 9, i['startedAtHourLocal'] as int),
        oldLevel: i['oldLevel'] as int,
        newLevel: i['newLevel'] as int,
        existingBadges: (i['existingBadges'] as List).cast<String>(),
      ));
      expect(result.toSet(), (c['expected'] as List).cast<String>().toSet(),
          reason: c['name'] as String);
    }
  });

  test('parity: pickWeightedIndex', () {
    for (final c in fx['weightedPick'] as List) {
      expect(
        pickWeightedIndex((c['weights'] as List).cast<int>(), c['roll'] as int),
        c['expected'],
        reason: '$c',
      );
    }
  });

  test('parity: evaluateVersionGate', () {
    for (final c in fx['versionGate'] as List) {
      final r = evaluateVersionGate(
        currentBuild: c['current'] as int,
        policy: VersionPolicy(
          minBuildNumber: c['min'] as int,
          latestBuildNumber: c['latest'] as int,
        ),
      );
      expect(r.name, c['expected'], reason: '$c');
    }
  });
}
