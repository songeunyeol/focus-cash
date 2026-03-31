import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../models/focus_session.dart';
import '../services/focus_service.dart';
import '../services/credit_service.dart';
import '../services/notification_service.dart';
import '../services/xp_service.dart';

enum FocusState { idle, focusing, completed, abandoned }

class FocusProvider extends ChangeNotifier {
  final FocusService _focusService = FocusService();
  final CreditService _creditService = CreditService();

  FocusState _state = FocusState.idle;
  FocusSession? _currentSession;
  int _remainingSeconds = 0;
  int _elapsedSeconds = 0;
  Timer? _timer;
  bool _isCompleting = false;
  int _earnedCredits = 0;
  int _earnedXp = 0;
  int _newLevel = 0;
  List<String> _newBadges = [];

  FocusState get state => _state;
  int get earnedXp => _earnedXp;
  int get newLevel => _newLevel;
  List<String> get newBadges => List.unmodifiable(_newBadges);
  FocusSession? get currentSession => _currentSession;
  int get remainingSeconds => _remainingSeconds;
  int get elapsedSeconds => _elapsedSeconds;
  int get elapsedMinutes => _elapsedSeconds ~/ 60;
  int get earnedCredits => _earnedCredits;
  double get progress => _currentSession != null
      ? _elapsedSeconds / (_currentSession!.targetMinutes * 60)
      : 0;

  Future<void> startFocus({
    required String userId,
    required int targetMinutes,
    required String hardcoreMode,
    required String tag,
    bool watchedStartAd = false,
  }) async {
    try {
      _currentSession = await _focusService.startSession(
        userId: userId,
        targetMinutes: targetMinutes,
        hardcoreMode: hardcoreMode,
        tag: tag,
        watchedStartAd: watchedStartAd,
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      _currentSession = FocusSession(
        id: 'local-${DateTime.now().millisecondsSinceEpoch}',
        userId: userId,
        targetMinutes: targetMinutes,
        hardcoreMode: hardcoreMode,
        tag: tag,
        watchedStartAd: watchedStartAd,
        startedAt: DateTime.now(),
      );
    }

    _remainingSeconds = targetMinutes * 60;
    _elapsedSeconds = 0;
    _state = FocusState.focusing;

    _startTimer();
    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_state != FocusState.focusing) return;

      _elapsedSeconds++;
      _remainingSeconds--;

      if (_remainingSeconds <= 0 && !_isCompleting) {
        _isCompleting = true;
        await _completeSession();
        return;
      }

      notifyListeners();
    });
  }

  /// 테스트용: 즉시 완료 처리
  Future<void> skipToComplete() async {
    if (_isCompleting) return;
    _isCompleting = true;
    _remainingSeconds = 0;
    _elapsedSeconds = _currentSession != null
        ? _currentSession!.targetMinutes * 60
        : _elapsedSeconds;
    await _completeSession();
  }

  Future<void> _completeSession() async {
    _timer?.cancel();

    if (_currentSession == null) return;

    final actualMinutes = _elapsedSeconds ~/ 60;

    final credits = _creditService.calculateSessionCredits(
      focusMinutes: actualMinutes,
      watchedStartAd: _currentSession!.watchedStartAd,
      watchedEndAd: false,
      hardcoreMode: _currentSession!.hardcoreMode,
    );

    _earnedCredits = credits;

    try {
      _currentSession = await _focusService.endSession(
        session: _currentSession!,
        actualMinutes: actualMinutes,
        creditsEarned: credits,
        completed: true,
      ).timeout(const Duration(seconds: 5));
      await _creditService.addCredits(
        userId: _currentSession!.userId,
        amount: credits,
        description: '${actualMinutes}분 집중 완료',
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      // Firebase 미설정 시 무시
    }

    // XP 먼저 계산 — 완료 화면에 XP/배지/레벨업 정보가 준비된 뒤 UI 업데이트
    await _awardXp(_currentSession!.userId, _currentSession!);

    final completedUserId = _currentSession!.userId;
    _state = FocusState.completed;
    notifyListeners();

    // 백그라운드 작업 (UI 불필요) — reset() 후 null 참조 방지
    _maybeGiveReferralBonus(completedUserId);
    _updateNotifications(completedUserId, credits);
  }

  Future<void> _awardXp(String userId, FocusSession session) async {
    try {
      final result = await XpService.instance.onSessionComplete(
        userId: userId,
        actualMinutes: session.actualMinutes,
        isHardcore: session.hardcoreMode == 'hardcore',
        startedAt: session.startedAt,
      );
      if (result.isNotEmpty) {
        _earnedXp = (result['xpGained'] as int? ?? 0) +
            (result['badgeXpGained'] as int? ?? 0);
        _newLevel = result['newLevel'] as int? ?? 0;
        _newBadges = (result['newBadges'] as List<dynamic>?)?.cast<String>() ?? [];
        // notifyListeners는 _completeSession에서 일괄 호출
      }
    } catch (_) {}
  }

  Future<void> _updateNotifications(String userId, int credits) async {
    try {
      final db = FirebaseFirestore.instance;
      final userDoc = await db.collection('users').doc(userId).get();
      final streak = userDoc.data()?['currentStreak'] as int? ?? 0;
      // 오늘 집중 완료 → 오늘 밤 알림 취소 후 내일 밤으로 재스케줄 (Duolingo 스타일)
      await NotificationService.instance
          .rescheduleStreakReminderToTomorrow(currentStreak: streak);
    } catch (_) {}
  }

  Future<void> _maybeGiveReferralBonus(String userId) async {
    try {
      final db = FirebaseFirestore.instance;
      final userDoc = await db.collection('users').doc(userId).get();
      final data = userDoc.data();
      if (data == null) return;

      final invitedBy = data['invitedBy'] as String? ?? '';
      final bonusGiven = data['inviteBonusGiven'] as bool? ?? false;

      if (invitedBy.isEmpty || bonusGiven) return;

      // 보너스 지급 플래그 먼저 설정 (중복 방지)
      await db.collection('users').doc(userId).update({'inviteBonusGiven': true});

      // 피초대자 보너스
      await _creditService.addCredits(
        userId: userId,
        amount: AppConstants.referralBonus,
        description: '친구 초대 보너스',
      );

      // 초대자 보너스
      await _creditService.addCredits(
        userId: invitedBy,
        amount: AppConstants.referralBonus,
        description: '친구 초대 보너스 (초대 성공)',
      );
    } catch (_) {}
  }

  Future<void> addStartAdBonus() async {
    if (_currentSession == null) return;

    try {
      await _creditService.addCredits(
        userId: _currentSession!.userId,
        amount: AppConstants.startAdBonus,
        description: '시작 광고 시청 보너스',
      );
    } catch (e) {
      // Firebase 미설정 시 무시
    }

    _earnedCredits += AppConstants.startAdBonus;
    notifyListeners();
  }

  Future<void> addEndAdBonus() async {
    if (_currentSession == null) return;

    final bonus = (_earnedCredits * AppConstants.endAdMultiplierRate).round();
    if (bonus <= 0) return;

    try {
      await _creditService.addCredits(
        userId: _currentSession!.userId,
        amount: bonus,
        description: '종료 광고 시청 보너스',
      );
    } catch (e) {
      // Firebase 미설정 시 무시
    }

    _earnedCredits += bonus;
    notifyListeners();
  }

  Future<void> abandonSession({bool nopenalty = false}) async {
    _timer?.cancel();

    if (_currentSession == null) return;

    final actualMinutes = _elapsedSeconds ~/ 60;

    _state = FocusState.abandoned;
    notifyListeners();

    try {
      _currentSession = await _focusService.endSession(
        session: _currentSession!,
        actualMinutes: actualMinutes,
        creditsEarned: 0,
        completed: false,
      ).timeout(const Duration(seconds: 5));

      if (!nopenalty && _currentSession!.hardcoreMode == 'hardcore') {
        await _creditService.applyPenalty(
          userId: _currentSession!.userId,
          penaltyRate: AppConstants.hardcorePenaltyRate,
        ).timeout(const Duration(seconds: 5));
      }
    } catch (e) {
      // Firebase 미설정 시 무시
    }

    _earnedCredits = 0;
  }

  void reset() {
    _timer?.cancel();
    _state = FocusState.idle;
    _currentSession = null;
    _remainingSeconds = 0;
    _elapsedSeconds = 0;
    _isCompleting = false;
    _earnedCredits = 0;
    _earnedXp = 0;
    _newLevel = 0;
    _newBadges = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
