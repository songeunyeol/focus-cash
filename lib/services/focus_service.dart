import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/focus_session.dart';

class FocusService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
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

  Future<FocusSession> endSession({
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

    // Update user stats
    await _updateUserStats(
      userId: session.userId,
      focusMinutes: actualMinutes,
      completed: completed,
    );

    return updatedSession;
  }

  Future<void> _updateUserStats({
    required String userId,
    required int focusMinutes,
    required bool completed,
  }) async {
    final userRef = _firestore.collection('users').doc(userId);

    await _firestore.runTransaction((transaction) async {
      final userDoc = await transaction.get(userRef);
      if (!userDoc.exists) return;

      final data = userDoc.data()!;
      final totalMinutes = (data['totalFocusMinutes'] as int? ?? 0);
      final todayMinutes = (data['todayFocusMinutes'] as int? ?? 0);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // 마지막 활동일 파싱
      final rawLastActive = data['lastActiveAt'];
      final lastActive = rawLastActive is Timestamp
          ? rawLastActive.toDate()
          : rawLastActive is String
              ? DateTime.tryParse(rawLastActive)
              : null;
      final lastActiveDay = lastActive != null
          ? DateTime(lastActive.year, lastActive.month, lastActive.day)
          : null;

      // 날짜가 바뀌었으면 오늘 집중 시간 리셋
      final isNewDay =
          lastActiveDay == null || !lastActiveDay.isAtSameMomentAs(today);
      final newTodayMinutes =
          isNewDay ? focusMinutes : todayMinutes + focusMinutes;

      final updates = <String, dynamic>{
        'totalFocusMinutes': totalMinutes + focusMinutes,
        'todayFocusMinutes': newTodayMinutes,
        'lastActiveAt': now.toIso8601String(),
        // 날짜가 바뀐 경우 todayCredits도 리셋 (addCredits보다 먼저 lastActiveAt을 오늘로
        // 설정하기 때문에, addCredits에서 isNewDay를 올바르게 판단할 수 없는 문제 방지)
        if (isNewDay) 'todayCredits': 0,
      };

      if (completed) {
        final currentStreak = data['currentStreak'] as int? ?? 0;
        final longestStreak = data['longestStreak'] as int? ?? 0;

        // 오늘 처음 완료한 경우에만 스트릭 증가
        final alreadyCountedToday = lastActiveDay != null &&
            lastActiveDay.isAtSameMomentAs(today);

        if (!alreadyCountedToday) {
          final yesterday = today.subtract(const Duration(days: 1));
          final isConsecutive = lastActiveDay != null &&
              lastActiveDay.isAtSameMomentAs(yesterday);

          // 어제 집중했으면 스트릭 +1, 아니면 1로 리셋
          final newStreak = isConsecutive ? currentStreak + 1 : 1;
          updates['currentStreak'] = newStreak;
          if (newStreak > longestStreak) {
            updates['longestStreak'] = newStreak;
          }
        }
      }

      transaction.update(userRef, updates);
    });
  }

  /// 앱 강제 종료 등으로 endedAt 없이 남은 미완료 세션 정리
  Future<void> cleanupOrphanedSessions(String userId) async {
    try {
      final snap = await _firestore
          .collection('focus_sessions')
          .where('userId', isEqualTo: userId)
          .where('completed', isNull: true)
          .get();

      // 2시간(최대 집중 시간) 이상 지난 세션만 포기 처리
      final cutoff = DateTime.now().subtract(const Duration(hours: 2));
      for (final doc in snap.docs) {
        final raw = doc.data()['startedAt'];
        final startedAt = raw is Timestamp
            ? raw.toDate()
            : raw is String
                ? DateTime.tryParse(raw)
                : null;
        if (startedAt != null && startedAt.isBefore(cutoff)) {
          await doc.reference.update({
            'completed': false,
            'actualMinutes': 0,
            'creditsEarned': 0,
            'endedAt': Timestamp.fromDate(DateTime.now()),
          });
        }
      }
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

  /// 기간별 집중 시간 랭킹 (상위 50명)
  Future<List<Map<String, dynamic>>> getRanking(String period) async {
    final now = DateTime.now();
    final DateTime since;
    switch (period) {
      case 'daily':
        since = DateTime(now.year, now.month, now.day);
      case 'monthly':
        since = DateTime(now.year, now.month, 1);
      case 'weekly':
      default:
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        since = DateTime(weekStart.year, weekStart.month, weekStart.day);
    }

    // 단일 필드 쿼리 → 복합 인덱스 불필요, completed 필터는 Dart에서 처리
    final snap = await _firestore
        .collection('focus_sessions')
        .where('startedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .get();

    // userId별 집중 시간 합산 (completed 필터 포함)
    final totals = <String, int>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      if (data['completed'] != true) continue;
      final uid = data['userId'] as String? ?? '';
      final mins = data['actualMinutes'] as int? ?? 0;
      if (uid.isEmpty) continue;
      totals[uid] = (totals[uid] ?? 0) + mins;
    }

    // 상위 50명 정렬
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top50 = sorted.take(50).toList();

    // 유저 정보 병렬 조회
    final userDocs = await Future.wait(
      top50.map((e) => _firestore.collection('users').doc(e.key).get()),
    );

    final result = <Map<String, dynamic>>[];
    for (int i = 0; i < top50.length; i++) {
      final uid = top50[i].key;
      final mins = top50[i].value;
      final userData = userDocs[i].data() ?? {};
      result.add({
        'rank': i + 1,
        'uid': uid,
        'name': (userData['displayName'] as String? ?? '').isNotEmpty
            ? userData['displayName'] as String
            : '집중러',
        'avatarIndex': userData['avatarIndex'] as int? ?? 0,
        'minutes': mins,
        'streak': userData['currentStreak'] as int? ?? 0,
      });
    }
    return result;
  }

  /// 친구 랭킹 조회
  Future<List<Map<String, dynamic>>> getFriendRanking(
    String period,
    List<String> friendUids,
    String myUid,
  ) async {
    final targetUids = {...friendUids, myUid}.toList();
    if (targetUids.isEmpty) return [];

    final now = DateTime.now();
    final DateTime since;
    switch (period) {
      case 'daily':
        since = DateTime(now.year, now.month, now.day);
      case 'monthly':
        since = DateTime(now.year, now.month, 1);
      case 'weekly':
      default:
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        since = DateTime(weekStart.year, weekStart.month, weekStart.day);
    }

    // 친구들 세션 조회 (whereIn만 사용 → 복합 인덱스 불필요)
    // completed·startedAt 필터는 Dart에서 처리
    final totals = <String, int>{};
    for (var i = 0; i < targetUids.length; i += 10) {
      final chunk = targetUids.sublist(
          i, i + 10 > targetUids.length ? targetUids.length : i + 10);
      final snap = await _firestore
          .collection('focus_sessions')
          .where('userId', whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        if (data['completed'] != true) continue;
        final raw = data['startedAt'];
        final startedAt = raw is Timestamp
            ? raw.toDate()
            : raw is String
                ? DateTime.tryParse(raw)
                : null;
        if (startedAt == null || startedAt.isBefore(since)) continue;
        final uid = data['userId'] as String? ?? '';
        final mins = data['actualMinutes'] as int? ?? 0;
        if (uid.isEmpty) continue;
        totals[uid] = (totals[uid] ?? 0) + mins;
      }
    }

    // 집중 기록 없는 친구도 0분으로 포함
    for (final uid in targetUids) {
      totals.putIfAbsent(uid, () => 0);
    }

    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final userDocs = await Future.wait(
      sorted.map((e) => _firestore.collection('users').doc(e.key).get()),
    );

    final result = <Map<String, dynamic>>[];
    for (int i = 0; i < sorted.length; i++) {
      final uid = sorted[i].key;
      final mins = sorted[i].value;
      final userData = userDocs[i].data() ?? {};
      result.add({
        'rank': i + 1,
        'uid': uid,
        'name': (userData['displayName'] as String? ?? '').isNotEmpty
            ? userData['displayName'] as String
            : '집중러',
        'avatarIndex': userData['avatarIndex'] as int? ?? 0,
        'minutes': mins,
        'streak': userData['currentStreak'] as int? ?? 0,
      });
    }
    return result;
  }

  Future<Map<String, int>> getWeeklyStats(String userId) async {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeek =
        DateTime(weekStart.year, weekStart.month, weekStart.day);

    final snapshot = await _firestore
        .collection('focus_sessions')
        .where('userId', isEqualTo: userId)
        .where('startedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek))
        .get();

    final dailyMinutes = <String, int>{};
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    for (final name in dayNames) {
      dailyMinutes[name] = 0;
    }

    for (final doc in snapshot.docs) {
      final session = FocusSession.fromMap(doc.data());
      final dayIndex = session.startedAt.weekday - 1;
      final dayName = dayNames[dayIndex];
      dailyMinutes[dayName] =
          (dailyMinutes[dayName] ?? 0) + session.actualMinutes;
    }

    return dailyMinutes;
  }
}
