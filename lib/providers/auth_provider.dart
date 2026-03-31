import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/focus_service.dart';
import '../services/notification_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FocusService _focusService = FocusService();

  UserModel? _user;
  bool _isLoading = false;
  String? _error;
  bool _isNewUser = false;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null || _authService.currentUser != null;
  bool get isNewUser => _isNewUser;
  String? get error => _error;

  Future<void> loadUser() async {

    _isLoading = true;
    notifyListeners();

    try {
      _user = await _authService.getUserModel();

      // 기존 유저 중 inviteCode 없는 경우 자동 생성
      if (_user != null && _user!.inviteCode.isEmpty) {
        final uid = _authService.currentUser?.uid ?? '';
        if (uid.isNotEmpty) {
          final code = uid.substring(0, 8).toUpperCase();
          try {
            await _authService.updateUserProfile(uid: uid, inviteCode: code);
            _user = _user!.copyWith(inviteCode: code);
          } catch (e) {
            debugPrint('초대코드 자동 생성 오류: $e');
          }
        }
      }

      // 로그인 후 스트릭 리마인더 등록 + 미완료 세션 정리
      if (_user != null) {
        NotificationService.instance
            .scheduleStreakReminder(currentStreak: _user!.currentStreak)
            .ignore();
        _focusService.cleanupOrphanedSessions(_user!.uid).ignore();
      }
    } catch (e) {
      debugPrint('loadUser 오류: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.signInWithGoogle();
      if (result == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }
      _isNewUser = await _authService.checkIsNewUser();
      if (!_isNewUser) await loadUser();
      return true;
    } catch (e) {
      _error = '구글 로그인에 실패했습니다';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithKakao() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.signInWithKakao();
      if (result == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }
      _isNewUser = await _authService.checkIsNewUser();
      if (!_isNewUser) await loadUser();
      return true;
    } catch (e) {
      debugPrint('카카오 로그인 오류: $e');
      _error = '카카오 로그인에 실패했습니다';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> completeSignup({
    required String displayName,
    required int avatarIndex,
    required bool marketingAgreed,
    String inviteCodeUsed = '',
  }) async {
    await _authService.completeSignup(
      displayName: displayName,
      avatarIndex: avatarIndex,
      marketingAgreed: marketingAgreed,
      inviteCodeUsed: inviteCodeUsed,
    );
    _isNewUser = false;
    await loadUser();
  }

  void updateUser(UserModel updatedUser) {
    _user = updatedUser;
    notifyListeners();
  }

  /// UI 업데이트 + Firestore 동기화
  Future<void> updateAndSaveUser(UserModel updatedUser) async {
    _user = updatedUser;
    notifyListeners();
    try {
      await _authService.updateUserProfile(
        uid: updatedUser.uid,
        displayName: updatedUser.displayName,
        avatarIndex: updatedUser.avatarIndex,
      );
    } catch (e) {
      debugPrint('프로필 저장 오류: $e');
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _user = null;
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    await _authService.deleteAccount();
    _user = null;
    notifyListeners();
  }
}
