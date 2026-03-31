import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class FriendService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── 초대 코드로 유저 검색 ────────────────────────────────
  Future<UserModel?> searchByInviteCode(String code) async {
    final snap = await _db
        .collection('users')
        .where('inviteCode', isEqualTo: code.toUpperCase())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return UserModel.fromMap(snap.docs.first.data());
  }

  // ── 닉네임으로 유저 검색 ─────────────────────────────────
  Future<List<UserModel>> searchByName(String name) async {
    if (name.trim().isEmpty) return [];
    final snap = await _db
        .collection('users')
        .where('displayName', isGreaterThanOrEqualTo: name)
        .where('displayName', isLessThanOrEqualTo: '$name\uf8ff')
        .limit(20)
        .get();
    return snap.docs.map((d) => UserModel.fromMap(d.data())).toList();
  }

  // ── 친구 요청 보내기 ─────────────────────────────────────
  Future<void> sendFriendRequest({
    required String fromUid,
    required String toUid,
  }) async {
    if (fromUid == toUid) return;

    // 이미 pending·accepted인 경우만 차단 (rejected면 재요청 허용)
    final existing = await _db
        .collection('friend_requests')
        .where('from', isEqualTo: fromUid)
        .where('to', isEqualTo: toUid)
        .get();
    final hasActive = existing.docs.any((d) {
      final s = d.data()['status'] as String? ?? '';
      return s == 'pending' || s == 'accepted';
    });
    if (hasActive) return;

    // 이미 친구인지 확인 (상대방이 수락한 경우)
    final reverse = await _db
        .collection('friend_requests')
        .where('from', isEqualTo: toUid)
        .where('to', isEqualTo: fromUid)
        .where('status', isEqualTo: 'accepted')
        .get();
    if (reverse.docs.isNotEmpty) return;

    // rejected 문서가 있으면 삭제 후 새로 생성
    for (final doc in existing.docs) {
      await doc.reference.delete();
    }

    await _db.collection('friend_requests').add({
      'from': fromUid,
      'to': toUid,
      'status': 'pending',
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  // ── 내가 보낸 친구 요청 취소 ──────────────────────────────
  Future<void> cancelFriendRequest({
    required String fromUid,
    required String toUid,
  }) async {
    final snap = await _db
        .collection('friend_requests')
        .where('from', isEqualTo: fromUid)
        .where('to', isEqualTo: toUid)
        .where('status', isEqualTo: 'pending')
        .get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }

  // ── 내가 보낸 대기중 요청 uid 스트림 ─────────────────────
  Stream<Set<String>> watchSentPendingUids(String uid) {
    return _db
        .collection('friend_requests')
        .where('from', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => d.data()['to'] as String)
            .toSet());
  }

  // ── 친구 요청 수락 ───────────────────────────────────────
  Future<void> acceptFriendRequest(String requestId) async {
    await _db.collection('friend_requests').doc(requestId).update({
      'status': 'accepted',
    });
  }

  // ── 친구 요청 거절 ───────────────────────────────────────
  Future<void> rejectFriendRequest(String requestId) async {
    await _db.collection('friend_requests').doc(requestId).update({
      'status': 'rejected',
    });
  }

  // ── 친구 삭제 ────────────────────────────────────────────
  Future<void> removeFriend({
    required String myUid,
    required String friendUid,
  }) async {
    final q1 = await _db
        .collection('friend_requests')
        .where('from', isEqualTo: myUid)
        .where('to', isEqualTo: friendUid)
        .where('status', isEqualTo: 'accepted')
        .get();
    final q2 = await _db
        .collection('friend_requests')
        .where('from', isEqualTo: friendUid)
        .where('to', isEqualTo: myUid)
        .where('status', isEqualTo: 'accepted')
        .get();
    for (final doc in [...q1.docs, ...q2.docs]) {
      await doc.reference.delete();
    }
  }

  // ── 받은 pending 요청 스트림 ─────────────────────────────
  Stream<List<Map<String, dynamic>>> watchPendingRequests(String uid) {
    return _db
        .collection('friend_requests')
        .where('to', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList());
  }

  // ── 친구 uid 목록 조회 ────────────────────────────────────
  Future<List<String>> getFriendUids(String uid) async {
    final q1 = await _db
        .collection('friend_requests')
        .where('from', isEqualTo: uid)
        .where('status', isEqualTo: 'accepted')
        .get();
    final q2 = await _db
        .collection('friend_requests')
        .where('to', isEqualTo: uid)
        .where('status', isEqualTo: 'accepted')
        .get();

    final uids = <String>{};
    for (final doc in q1.docs) {
      uids.add(doc.data()['to'] as String);
    }
    for (final doc in q2.docs) {
      uids.add(doc.data()['from'] as String);
    }
    return uids.toList();
  }

  // ── uid로 유저 조회 ───────────────────────────────────────
  Future<UserModel?> getUserByUid(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!);
  }

  // ── 친구 유저 모델 스트림 ─────────────────────────────────
  // 보안 규칙 호환: 전체 조회 대신 본인 관련 두 쿼리를 머지
  Stream<List<UserModel>> watchFriends(String uid) {
    QuerySnapshot<Map<String, dynamic>>? latestFrom;
    QuerySnapshot<Map<String, dynamic>>? latestTo;
    StreamSubscription? sub1;
    StreamSubscription? sub2;
    late StreamController<List<UserModel>> controller;

    Future<void> rebuild() async {
      final friendUids = <String>{};
      for (final doc in (latestFrom?.docs ?? [])) {
        friendUids.add(doc.data()['to'] as String);
      }
      for (final doc in (latestTo?.docs ?? [])) {
        friendUids.add(doc.data()['from'] as String);
      }
      if (friendUids.isEmpty) {
        controller.add([]);
        return;
      }
      try {
        final users = await Future.wait(
          friendUids.map((fUid) => _db.collection('users').doc(fUid).get()),
        );
        controller.add(users
            .where((d) => d.exists)
            .map((d) => UserModel.fromMap(d.data()!))
            .toList());
      } catch (_) {}
    }

    controller = StreamController<List<UserModel>>(
      onListen: () {
        sub1 = _db
            .collection('friend_requests')
            .where('from', isEqualTo: uid)
            .where('status', isEqualTo: 'accepted')
            .snapshots()
            .listen((snap) {
          latestFrom = snap;
          rebuild();
        });
        sub2 = _db
            .collection('friend_requests')
            .where('to', isEqualTo: uid)
            .where('status', isEqualTo: 'accepted')
            .snapshots()
            .listen((snap) {
          latestTo = snap;
          rebuild();
        });
      },
      onCancel: () {
        sub1?.cancel();
        sub2?.cancel();
        controller.close();
      },
    );

    return controller.stream;
  }
}
