import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/constants.dart';

class XpService {
  XpService._();
  static final XpService instance = XpService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // ── 출석 체크 ──────────────────────────────
  // 오늘 첫 실행이면 XP 지급. 반환값: 지급된 XP (0이면 이미 체크됨)
  Future<int> checkIn(String userId) async {
    try {
      final today = _todayStr();
      final ref = _db.collection('users').doc(userId);

      return await _db.runTransaction<int>((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return 0;

        final lastCheckIn = snap.data()?['lastCheckInDate'] as String? ?? '';
        if (lastCheckIn == today) return 0; // 이미 체크인함

        final currentXp = snap.data()?['xp'] as int? ?? 0;
        final newXp = currentXp + AppConstants.checkInXp;
        final newLevel = AppConstants.levelFromXp(newXp);

        tx.update(ref, {
          'lastCheckInDate': today,
          'xp': newXp,
          'level': newLevel,
        });

        return AppConstants.checkInXp;
      });
    } catch (_) {
      return 0;
    }
  }

  // ── 집중 완료 XP 지급 ──────────────────────
  // 반환값: {xpGained, oldLevel, newLevel, newBadges}
  Future<Map<String, dynamic>> onSessionComplete({
    required String userId,
    required int actualMinutes,
    required bool isHardcore,
    required DateTime startedAt,
  }) async {
    try {
      final ref = _db.collection('users').doc(userId);

      return await _db.runTransaction<Map<String, dynamic>>((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return {};

        final data = snap.data()!;
        final currentXp = data['xp'] as int? ?? 0;
        final oldLevel = data['level'] as int? ?? 1;
        final existingBadges = (data['badges'] as List<dynamic>?)?.cast<String>() ?? [];
        final totalMinutes = data['totalFocusMinutes'] as int? ?? 0;
        final currentStreak = data['currentStreak'] as int? ?? 0;
        final hardcoreCount = data['hardcoreSessionCount'] as int? ?? 0;
        final todayMinutes = data['todayFocusMinutes'] as int? ?? 0;

        // XP 계산
        final xpGain = isHardcore
            ? (actualMinutes * AppConstants.focusXpPerMinute * AppConstants.hardcoreXpMultiplier).round()
            : (actualMinutes * AppConstants.focusXpPerMinute).round();

        int totalXp = currentXp + xpGain;
        int newHardcoreCount = isHardcore ? hardcoreCount + 1 : hardcoreCount;

        // 배지 체크
        final newBadgeIds = <String>[];
        void tryBadge(String id) {
          if (!existingBadges.contains(id) && !newBadgeIds.contains(id)) {
            newBadgeIds.add(id);
            totalXp += AppConstants.badgeXp;
          }
        }

        // first_focus (첫 세션: 이전 누적 시간이 0인 경우에만)
        if (totalMinutes == 0) tryBadge('first_focus');

        // focus_10h (600분)
        if (totalMinutes + actualMinutes >= 600) tryBadge('focus_10h');

        // focus_100h (6000분)
        if (totalMinutes + actualMinutes >= 6000) tryBadge('focus_100h');

        // streak_7 / streak_30
        // FocusService._updateUserStats가 XP 지급 후 실행되므로
        // 현재 값에 +1 보정해서 체크
        final effectiveStreak = currentStreak + 1;
        if (effectiveStreak >= 7) tryBadge('streak_7');
        if (effectiveStreak >= 30) tryBadge('streak_30');

        // hardcore_10
        if (newHardcoreCount >= 10) tryBadge('hardcore_10');

        // early_bird (오전 6시 이전 시작)
        if (startedAt.hour < 6) tryBadge('early_bird');

        // night_owl (23시~01시 사이 시작)
        if (startedAt.hour >= 23 || startedAt.hour < 1) tryBadge('night_owl');

        // full_day (하루 120분)
        if (todayMinutes + actualMinutes >= 120) tryBadge('full_day');

        // 레벨 계산
        final newLevel = AppConstants.levelFromXp(totalXp);

        // level_5, level_10 배지
        if (newLevel >= 5 && oldLevel < 5) tryBadge('level_5');
        if (newLevel >= 10 && oldLevel < 10) tryBadge('level_10');

        // Firestore 업데이트
        final updatedBadges = [...existingBadges, ...newBadgeIds];
        final updates = <String, dynamic>{
          'xp': totalXp,
          'level': newLevel,
          'badges': updatedBadges,
          if (isHardcore) 'hardcoreSessionCount': newHardcoreCount,
        };
        tx.update(ref, updates);

        return {
          'xpGained': xpGain,
          'badgeXpGained': newBadgeIds.length * AppConstants.badgeXp,
          'oldLevel': oldLevel,
          'newLevel': newLevel,
          'newBadges': newBadgeIds,
        };
      });
    } catch (_) {
      return {};
    }
  }

  // ── 레벨업 배지 체크 (출석 체크 후) ────────
  Future<List<String>> checkLevelBadges({
    required String userId,
    required int oldLevel,
    required int newLevel,
    required List<String> existingBadges,
  }) async {
    try {
      final newBadgeIds = <String>[];
      if (newLevel >= 5 && oldLevel < 5 && !existingBadges.contains('level_5')) {
        newBadgeIds.add('level_5');
      }
      if (newLevel >= 10 && oldLevel < 10 && !existingBadges.contains('level_10')) {
        newBadgeIds.add('level_10');
      }
      if (newBadgeIds.isEmpty) return [];

      final ref = _db.collection('users').doc(userId);
      await ref.update({
        'badges': FieldValue.arrayUnion(newBadgeIds),
        'xp': FieldValue.increment(newBadgeIds.length * AppConstants.badgeXp),
      });
      return newBadgeIds;
    } catch (_) {
      return [];
    }
  }

  // ── 초대 성공 시 inviteCount 증가 + 배지 체크 ──
  Future<void> onInviteSuccess(String inviterUid) async {
    try {
      final ref = _db.collection('users').doc(inviterUid);
      await _db.runTransaction<void>((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return;
        final count = (snap.data()?['inviteCount'] as int? ?? 0) + 1;
        final badges = (snap.data()?['badges'] as List<dynamic>?)?.cast<String>() ?? [];
        final updates = <String, dynamic>{'inviteCount': count};
        if (count >= 3 && !badges.contains('invite_3')) {
          updates['badges'] = [...badges, 'invite_3'];
          updates['xp'] = FieldValue.increment(AppConstants.badgeXp);
        }
        tx.update(ref, updates);
      });
    } catch (_) {}
  }
}
