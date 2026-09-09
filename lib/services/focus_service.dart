import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../config/constants.dart';
import '../domain/badge_rules.dart';
import '../domain/streak_rules.dart';
import '../models/focus_session.dart';

/// 세션 완료가 사용자 문서에 남긴 결과. 완료 화면이 그대로 보여준다.
class SessionOutcome {
  const SessionOutcome({
    required this.xpGained,
    required this.badgeXpGained,
    required this.oldLevel,
    required this.newLevel,
    required this.newBadges,
    required this.currentStreak,
    required this.totalMinutesBefore,
  });

  static const SessionOutcome empty = SessionOutcome(
    xpGained: 0,
    badgeXpGained: 0,
    oldLevel: 0,
    newLevel: 0,
    newBadges: <String>[],
    currentStreak: 0,
    totalMinutesBefore: -1,
  );

  final int xpGained;
  final int badgeXpGained;
  final int oldLevel;
  final int newLevel;
  final List<String> newBadges;
  final int currentStreak;

  /// 이번 세션 반영 전 누적 분. 0 이면 생애 첫 완료다 (첫 집중 보너스 판정용).
  final int totalMinutesBefore;

  bool get leveledUp => newLevel > oldLevel;
  bool get isFirstEverSession => totalMinutesBefore == 0;
}

class FocusService {
  FocusService({FirebaseFirestore? firestore}) : _injected = firestore;

  final FirebaseFirestore? _injected;
  late final FirebaseFirestore _firestore =
      _injected ?? FirebaseFirestore.instance;
  final _uuid = const Uuid();

  Future<FocusSession> startSession({
    required String userId,
    required int targetMinutes,
    required String hardcoreMode,
    required String tag,
    bool watchedStartAd = false,
  }) async {
    final session = FocusSession(
      id: _uuid.v4(),
      userId: userId,
      targetMinutes: targetMinutes,
      hardcoreMode: hardcoreMode,
      tag: tag,
      watchedStartAd: watchedStartAd,
      startedAt: DateTime.now(),
    );

    await _firestore
        .collection('focus_sessions')
        .doc(session.id)
        .set(session.toMap());

    return session;
  }

  /// 세션을 종료하고 사용자 통계·스트릭·XP·배지를 **한 트랜잭션**으로 반영한다.
  ///
  /// 이전에는 통계(여기) → 크레딧 → XP(XpService) 세 번에 나눠 썼고, XP 단계가
  /// 이미 갱신된 누적값을 "반영 전" 값으로 읽어 first_focus 가 절대 안 나오고
  /// streak_7 이 6일차에 나오는 문제가 있었다. 한 곳에서 before 값을 읽고 전부 계산한다.
  Future<(FocusSession, SessionOutcome)> endSession({
    required FocusSession session,
    required int actualMinutes,
    required int creditsEarned,
    required bool completed,
    bool watchedEndAd = false,
  }) async {
    final updatedSession = session.copyWith(
      actualMinutes: actualMinutes,
      creditsEarned: creditsEarned,
      completed: completed,
      watchedEndAd: watchedEndAd,
      endedAt: DateTime.now(),
    );

    await _firestore
        .collection('focus_sessions')
        .doc(session.id)
        .update(updatedSession.toMap());

    final outcome = await _applyCompletion(
      userId: session.userId,
      focusMinutes: actualMinutes,
      completed: completed,
      isHardcore: session.hardcoreMode == 'hardcore',
      startedAt: session.startedAt,
    );

    return (updatedSession, outcome);
  }

  Future<SessionOutcome> _applyCompletion({
    required String userId,
    required int focusMinutes,
    required bool completed,
    required bool isHardcore,
    required DateTime startedAt,
  }) async {
    final userRef = _firestore.collection('users').doc(userId);

    return _firestore.runTransaction<SessionOutcome>((transaction) async {
      final userDoc = await transaction.get(userRef);
      if (!userDoc.exists) return SessionOutcome.empty;

      final data = userDoc.data()!;
      final now = DateTime.now();
      final todayKey = _dateKey(now);

      final totalBefore = data['totalFocusMinutes'] as int? ?? 0;
      final todayBefore = (data['focusDate'] as String? ?? '') == todayKey
          ? (data['todayFocusMinutes'] as int? ?? 0)
          : 0;

      final updates = <String, dynamic>{
        'totalFocusMinutes': totalBefore + focusMinutes,
        'todayFocusMinutes': todayBefore + focusMinutes,
        'focusDate': todayKey,
        'lastActiveAt': now.toIso8601String(),
      };

      if (!completed) {
        transaction.update(userRef, updates);
        return SessionOutcome.empty;
      }

      // ── 스트릭 ─────────────────────────────────────────
      // 기준은 lastFocusDate. 구버전 문서에는 없으므로 lastActiveAt 으로 한 번 폴백한다.
      final lastFocusRaw = data['lastFocusDate'] as String? ?? '';
      final lastFocus = lastFocusRaw.isNotEmpty
          ? DateTime.tryParse(lastFocusRaw)
          : _legacyLastActive(data['lastActiveAt']);
      final streak = computeStreak(
        today: now,
        lastFocusDate: lastFocus,
        currentStreak: data['currentStreak'] as int? ?? 0,
        longestStreak: data['longestStreak'] as int? ?? 0,
      );
      updates['currentStreak'] = streak.currentStreak;
      updates['longestStreak'] = streak.longestStreak;
      updates['lastFocusDate'] = todayKey;

      // ── XP · 레벨 · 배지 ───────────────────────────────
      final xpBefore = data['xp'] as int? ?? 0;
      final oldLevel = data['level'] as int? ?? 1;
      final existingBadges =
          (data['badges'] as List<dynamic>?)?.cast<String>() ?? <String>[];
      final hardcoreBefore = data['hardcoreSessionCount'] as int? ?? 0;
      final hardcoreAfter = isHardcore ? hardcoreBefore + 1 : hardcoreBefore;

      final xpGain = xpForSession(actualMinutes: focusMinutes, isHardcore: isHardcore);
      final levelAfterXp = AppConstants.levelFromXp(xpBefore + xpGain);

      final newBadges = evaluateBadges(BadgeInput(
        totalMinutesBefore: totalBefore,
        actualMinutes: focusMinutes,
        streakAfter: streak.currentStreak,
        hardcoreCountAfter: hardcoreAfter,
        todayMinutesBefore: todayBefore,
        startedAt: startedAt,
        oldLevel: oldLevel,
        newLevel: levelAfterXp,
        existingBadges: existingBadges,
      ));
      final badgeXp = newBadges.length * AppConstants.badgeXp;
      final totalXp = xpBefore + xpGain + badgeXp;
      final newLevel = AppConstants.levelFromXp(totalXp);

      updates['xp'] = totalXp;
      updates['level'] = newLevel;
      if (newBadges.isNotEmpty) {
        updates['badges'] = [...existingBadges, ...newBadges];
      }
      if (isHardcore) updates['hardcoreSessionCount'] = hardcoreAfter;

      transaction.update(userRef, updates);

      return SessionOutcome(
        xpGained: xpGain,
        badgeXpGained: badgeXp,
        oldLevel: oldLevel,
        newLevel: newLevel,
        newBadges: newBadges,
        currentStreak: streak.currentStreak,
        totalMinutesBefore: totalBefore,
      );
    });
  }

  static DateTime? _legacyLastActive(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  /// 앱 강제 종료 등으로 endedAt 없이 남은 미완료 세션 정리.
  ///
  /// `completed` 는 시작 시 false 로 기록되므로 isNull 로는 절대 잡히지 않았다.
  /// 종료 여부는 `endedAt` 이 말해준다.
  Future<void> cleanupOrphanedSessions(String userId) async {
    try {
      final snap = await _firestore
          .collection('focus_sessions')
          .where('userId', isEqualTo: userId)
          .where('endedAt', isNull: true)
          .get();

      // 최대 집중 시간(2시간) + 복구 유예를 넘긴 것만 포기 처리한다.
      // 그 안의 것은 SessionRecovery 가 이어하기/완료 판정을 맡는다.
      final cutoff = DateTime.now().subtract(const Duration(hours: 26));
      final batch = _firestore.batch();
      var count = 0;
      for (final doc in snap.docs) {
        final raw = doc.data()['startedAt'];
        final startedAt = raw is Timestamp
            ? raw.toDate()
            : raw is String
                ? DateTime.tryParse(raw)
                : null;
        if (startedAt != null && startedAt.isBefore(cutoff)) {
          batch.update(doc.reference, {
            'completed': false,
            'actualMinutes': 0,
            'creditsEarned': 0,
            'endedAt': Timestamp.fromDate(DateTime.now()),
          });
          count++;
        }
      }
      if (count > 0) await batch.commit();
    } catch (_) {}
  }

  Future<List<FocusSession>> getUserSessions(String userId,
      {int limit = 30}) async {
    final snapshot = await _firestore
        .collection('focus_sessions')
        .where('userId', isEqualTo: userId)
        .orderBy('startedAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => FocusSession.fromMap(doc.data()))
        .toList();
  }

  static DateTime _periodStart(String period, DateTime now) {
    switch (period) {
      case 'daily':
        return DateTime(now.year, now.month, now.day);
      case 'monthly':
        return DateTime(now.year, now.month, 1);
      case 'weekly':
      default:
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        return DateTime(weekStart.year, weekStart.month, weekStart.day);
    }
  }

  /// 기간별 집중 시간 랭킹 (상위 50명)
  ///
  /// NOTE: 기간 내 세션을 전부 읽어 클라이언트에서 합산한다. 사용자가 늘면
  /// `daily_stats` 집계 문서로 옮겨야 한다 (docs/SERVER_MIGRATION.md 참고).
  Future<List<Map<String, dynamic>>> getRanking(String period) async {
    final since = _periodStart(period, DateTime.now());

    final snap = await _firestore
        .collection('focus_sessions')
        .where('startedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .get();

    final totals = <String, int>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      if (data['completed'] != true) continue;
      final uid = data['userId'] as String? ?? '';
      final mins = data['actualMinutes'] as int? ?? 0;
      if (uid.isEmpty) continue;
      totals[uid] = (totals[uid] ?? 0) + mins;
    }

    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return _attachUserInfo(sorted.take(50).toList());
  }

  /// 친구 랭킹 조회
  Future<List<Map<String, dynamic>>> getFriendRanking(
    String period,
    List<String> friendUids,
    String myUid,
  ) async {
    final targetUids = {...friendUids, myUid}.toList();
    if (targetUids.isEmpty) return [];

    final since = _periodStart(period, DateTime.now());

    final totals = <String, int>{};
    for (var i = 0; i < targetUids.length; i += 10) {
      final chunk = targetUids.sublist(
          i, i + 10 > targetUids.length ? targetUids.length : i + 10);
      final snap = await _firestore
          .collection('focus_sessions')
          .where('userId', whereIn: chunk)
          .where('startedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
          .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        if (data['completed'] != true) continue;
        final uid = data['userId'] as String? ?? '';
        final mins = data['actualMinutes'] as int? ?? 0;
        if (uid.isEmpty) continue;
        totals[uid] = (totals[uid] ?? 0) + mins;
      }
    }

    for (final uid in targetUids) {
      totals.putIfAbsent(uid, () => 0);
    }

    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return _attachUserInfo(sorted);
  }

  Future<List<Map<String, dynamic>>> _attachUserInfo(
      List<MapEntry<String, int>> ranked) async {
    final userDocs = await Future.wait(
      ranked.map((e) => _firestore.collection('users').doc(e.key).get()),
    );

    final result = <Map<String, dynamic>>[];
    for (int i = 0; i < ranked.length; i++) {
      final userData = userDocs[i].data() ?? {};
      result.add({
        'rank': i + 1,
        'uid': ranked[i].key,
        'name': (userData['displayName'] as String? ?? '').isNotEmpty
            ? userData['displayName'] as String
            : '집중러',
        'avatarIndex': userData['avatarIndex'] as int? ?? 0,
        'minutes': ranked[i].value,
        'streak': userData['currentStreak'] as int? ?? 0,
      });
    }
    return result;
  }

  /// 이번 주 요일별 집중 분. 완료된 세션만 센다 (캘린더·랭킹과 같은 기준).
  Future<Map<String, int>> getWeeklyStats(String userId) async {
    final startOfWeek = _periodStart('weekly', DateTime.now());

    final snapshot = await _firestore
        .collection('focus_sessions')
        .where('userId', isEqualTo: userId)
        .where('startedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek))
        .get();

    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dailyMinutes = <String, int>{for (final d in dayNames) d: 0};

    for (final doc in snapshot.docs) {
      final session = FocusSession.fromMap(doc.data());
      if (!session.completed) continue;
      final dayName = dayNames[session.startedAt.weekday - 1];
      dailyMinutes[dayName] = (dailyMinutes[dayName] ?? 0) + session.actualMinutes;
    }

    return dailyMinutes;
  }

  /// 한 달치 날짜별 집중 분 (`yyyy-MM-dd` → 분). 완료된 세션만. 캘린더 탭이 쓴다.
  /// (인덱스: userId + completed + startedAt — firestore.indexes.json)
  Future<Map<String, int>> getMonthlyMinutes(
      String userId, DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    final snap = await _firestore
        .collection('focus_sessions')
        .where('userId', isEqualTo: userId)
        .where('completed', isEqualTo: true)
        .where('startedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('startedAt', isLessThan: Timestamp.fromDate(end))
        .get();

    final result = <String, int>{};
    for (final doc in snap.docs) {
      final s = FocusSession.fromMap(doc.data());
      final key = _dateKey(s.startedAt);
      result[key] = (result[key] ?? 0) + s.actualMinutes;
    }
    return result;
  }

  /// 특정 날짜의 완료 세션 목록 (시작 시각 순).
  Future<List<FocusSession>> getSessionsOnDay(
      String userId, DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final snap = await _firestore
        .collection('focus_sessions')
        .where('userId', isEqualTo: userId)
        .where('completed', isEqualTo: true)
        .where('startedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('startedAt', isLessThan: Timestamp.fromDate(end))
        .orderBy('startedAt')
        .get();
    return snap.docs.map((d) => FocusSession.fromMap(d.data())).toList();
  }

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
