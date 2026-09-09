import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' hide User;
import '../models/user_model.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _injectedAuth = auth,
        _injectedDb = firestore;

  final FirebaseAuth? _injectedAuth;
  final FirebaseFirestore? _injectedDb;
  late final FirebaseAuth _auth = _injectedAuth ?? FirebaseAuth.instance;
  late final FirebaseFirestore _firestore =
      _injectedDb ?? FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ───────────────────────────────────────────
  // 구글 로그인
  // ───────────────────────────────────────────
  Future<UserCredential?> signInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return null; // 사용자가 취소

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    return userCredential;
  }

  // ───────────────────────────────────────────
  // 카카오 로그인
  // ───────────────────────────────────────────
  Future<UserCredential?> signInWithKakao() async {
    // 카카오톡 설치 여부에 따라 분기
    if (await isKakaoTalkInstalled()) {
      await UserApi.instance.loginWithKakaoTalk();
    } else {
      await UserApi.instance.loginWithKakaoAccount();
    }

    // 카카오 사용자 정보 조회
    final kakaoUser = await UserApi.instance.me();
    final kakaoId = kakaoUser.id;
    final kakaoName =
        kakaoUser.kakaoAccount?.profile?.nickname ?? '카카오 유저';

    // 카카오 ID로 Firebase 이메일/비밀번호 생성 (서버 없는 방식)
    final email = 'kakao_$kakaoId@focuscash.app';
    final password = 'FCS2024_K_$kakaoId';

    try {
      // 기존 유저 로그인
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      // user-not-found 또는 invalid-credential → 신규 유저로 처리
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        final userCredential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        await userCredential.user?.updateDisplayName(kakaoName);
        return userCredential;
      }
      rethrow;
    }
  }

  // 신규 유저 여부 확인 (Firestore 문서 없으면 신규)
  Future<bool> checkIsNewUser() async {
    final user = currentUser;
    if (user == null) return false;
    final doc = await _firestore.collection('users').doc(user.uid).get();
    return !doc.exists;
  }

  // 회원가입 완료 (약관 동의 + 프로필 저장)
  Future<void> completeSignup({
    required String displayName,
    required int avatarIndex,
    required bool marketingAgreed,
    String inviteCodeUsed = '', // 입력한 초대 코드 (선택)
  }) async {
    final user = currentUser;
    if (user == null) return;

    final now = DateTime.now();
    // 내 초대 코드 = uid 앞 8자리 대문자
    final myInviteCode = user.uid.substring(0, 8).toUpperCase();

    // 초대 코드로 초대자 uid 조회
    String inviterUid = '';
    if (inviteCodeUsed.isNotEmpty) {
      final snap = await _firestore
          .collection('users')
          .where('inviteCode', isEqualTo: inviteCodeUsed.toUpperCase())
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        inviterUid = snap.docs.first.data()['uid'] as String? ?? '';
      }
    }

    // 가입 보너스는 여기서 주지 않는다. 탈퇴→재가입으로 무한 파밍되던 구멍이라
    // 첫 집중 완료 시점(FocusProvider)에 [AppConstants.firstFocusBonus] 로 지급한다.
    final userModel = UserModel(
      uid: user.uid,
      phoneNumber: user.phoneNumber ?? '',
      displayName: displayName,
      avatarIndex: avatarIndex,
      totalCredits: 0,
      termsAgreedAt: now,
      marketingAgreed: marketingAgreed,
      createdAt: now,
      lastActiveAt: now,
      inviteCode: myInviteCode,
      invitedBy: inviterUid,
    );

    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(userModel.toMap());
  }

  Future<void> updateUserProfile({
    required String uid,
    String? displayName,
    int? avatarIndex,
    String? inviteCode,
  }) async {
    final updates = <String, dynamic>{};
    if (displayName != null) updates['displayName'] = displayName;
    if (avatarIndex != null) updates['avatarIndex'] = avatarIndex;
    if (inviteCode != null) updates['inviteCode'] = inviteCode;
    if (updates.isEmpty) return;
    await _firestore.collection('users').doc(uid).update(updates);
  }

  /// 마케팅 수신 동의 변경 (알림 설정 화면). 철회 경로는 법적으로 필수다.
  Future<void> updateMarketingAgreed({
    required String uid,
    required bool agreed,
  }) async {
    await _firestore.collection('users').doc(uid).update({
      'marketingAgreed': agreed,
    });
  }

  Future<UserModel?> getUserModel() async {
    final user = currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return null;

    return UserModel.fromMap(doc.data()!);
  }

  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await _auth.signOut();
  }

  /// 계정 탈퇴.
  ///
  /// 순서가 중요하다. Auth 계정 삭제는 `requires-recent-login` 으로 거부될 수 있으므로
  /// **먼저** 시도한다. 데이터를 지운 뒤 Auth 삭제가 실패하면 "users 문서는 없는데 계정은 남은"
  /// 상태가 되고, 다음 로그인이 신규 가입으로 처리된다. 삭제된 사용자의 ID 토큰은 만료 전까지
  /// 유효하므로 뒤따르는 Firestore 정리는 통과한다.
  ///
  /// 개인정보는 남기지 않는다 — 특히 gifticon_codes 의 배송지·연락처와 user_notes.
  Future<void> deleteAccount() async {
    final user = currentUser;
    if (user == null) return;
    final uid = user.uid;

    await GoogleSignIn().signOut();
    await user.delete(); // requires-recent-login 이면 여기서 throw → 데이터는 그대로

    Future<void> deleteWhere(String collection, String field) async {
      final snap = await _firestore
          .collection(collection)
          .where(field, isEqualTo: uid)
          .get();
      await _deleteAll(snap.docs);
    }

    await deleteWhere('focus_sessions', 'userId');
    await deleteWhere('credit_transactions', 'userId');
    await deleteWhere('user_notes', 'userId');
    await deleteWhere('raffle_entries', 'userId');
    await deleteWhere('friend_requests', 'from');
    await deleteWhere('friend_requests', 'to');

    // 기프티콘 문서는 재고·정산 기록이므로 남기되, 개인정보 필드만 비운다.
    final gifticons = await _firestore
        .collection('gifticon_codes')
        .where('usedBy', isEqualTo: uid)
        .get();
    final scrub = _firestore.batch();
    for (final doc in gifticons.docs) {
      scrub.update(doc.reference, {
        'deliveryName': '',
        'deliveryPhone': '',
        'deliveryAddress': '',
      });
    }
    await scrub.commit();

    await _firestore.collection('users').doc(uid).delete();
  }

  /// Firestore 배치는 500건 제한이 있어 나눠서 지운다.
  Future<void> _deleteAll(List<QueryDocumentSnapshot> docs) async {
    for (var i = 0; i < docs.length; i += 400) {
      final batch = _firestore.batch();
      for (final doc in docs.skip(i).take(400)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }
}
