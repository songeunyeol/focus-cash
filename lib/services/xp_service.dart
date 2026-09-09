import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/constants.dart';

/// 세션 완료 XP·배지는 [FocusService.endSession] 이 통계와 같은 트랜잭션에서 처리한다.
/// 여기에는 세션과 무관한 XP 경로(출석·초대)만 남긴다.
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
        if (lastCheckIn == today) return 0;

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

  // ── 초대 성공 시 inviteCount 증가 + 배지 체크 ──
  Future<void> onInviteSuccess(String inviterUid) async {
    try {
      final ref = _db.collection('users').doc(inviterUid);
      await _db.runTransaction<void>((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return;
        final count = (snap.data()?['inviteCount'] as int? ?? 0) + 1;
        final badges =
            (snap.data()?['badges'] as List<dynamic>?)?.cast<String>() ?? [];
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
