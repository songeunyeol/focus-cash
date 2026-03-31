import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' hide User;
import '../models/user_model.dart';
import '../config/constants.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

    final userModel = UserModel(
      uid: user.uid,
      phoneNumber: user.phoneNumber ?? '',
      displayName: displayName,
      avatarIndex: avatarIndex,
      totalCredits: AppConstants.signupBonus,
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

    await _firestore.collection('credit_transactions').add({
      'userId': user.uid,
      'amount': AppConstants.signupBonus,
      'type': 'earn',
      'description': '가입 보너스',
      'createdAt': now.toIso8601String(),
    });
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

  Future<void> deleteAccount() async {
    final user = currentUser;
    if (user == null) return;

    final uid = user.uid;

    // focus_sessions 삭제
    final sessions = await _firestore
        .collection('focus_sessions')
        .where('userId', isEqualTo: uid)
        .get();
    for (final doc in sessions.docs) {
      await doc.reference.delete();
    }

    // credit_transactions 삭제
    final transactions = await _firestore
        .collection('credit_transactions')
        .where('userId', isEqualTo: uid)
        .get();
    for (final doc in transactions.docs) {
      await doc.reference.delete();
    }

    // friend_requests 삭제 (내가 보냈거나 받은 것 모두)
    final sentRequests = await _firestore
        .collection('friend_requests')
        .where('from', isEqualTo: uid)
        .get();
    for (final doc in sentRequests.docs) {
      await doc.reference.delete();
    }
    final receivedRequests = await _firestore
        .collection('friend_requests')
        .where('to', isEqualTo: uid)
        .get();
    for (final doc in receivedRequests.docs) {
      await doc.reference.delete();
    }

    // users 문서 삭제
    await _firestore.collection('users').doc(uid).delete();

    // Firebase Auth 계정 삭제
    await GoogleSignIn().signOut();
    await user.delete();
  }
}
