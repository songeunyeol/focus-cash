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

  /// 벽시계 기준 경과 시간 계산을 위한 보조 상태.
  /// _elapsedSeconds 를 1초마다 누산하면 앱이 스로틀될 때 시간이 어긋나므로
  /// startedAt 과의 차이로 매 틱 재계산한다.
  DateTime? _lastTickAt;

  /// 단조 시계. 기기 시각 조작을 감지하는 교차 검증용.
  /// (딥슬립 중에는 멈출 수 있어 경과 시간의 주 기준으로는 쓰지 않는다)
  final Stopwatch _monotonic = Stopwatch();

  /// 전면 상태에서 벽시계가 비정상적으로 점프한 정황
  bool _clockTampered = false;

  /// 마지막 틱 이후 앱이 백그라운드를 거쳤는지.
  /// 백그라운드 구간의 시간 공백은 정상이므로 시각 조작 판정에서 제외한다.
  bool _sawPauseSinceLastTick = false;
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
  bool get clockTampered => _clockTampered;

  /// 앱이 백그라운드로 내려갔음을 알린다. 화면의 라이프사이클 훅에서 호출한다.
  void onAppPaused() => _sawPauseSinceLastTick = true;
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
    _clockTampered = false;
    _lastTickAt = DateTime.now();
    _monotonic
      ..reset()
      ..start();
    _state = FocusState.focusing;

    _startTimer();
    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  Future<void> _tick() async {
    if (_state != FocusState.focusing) return;

    _detectClockJump();
    syncElapsed();

    if (_remainingSeconds <= 0 && !_isCompleting) {
      _isCompleting = true;
      await _completeSession();
      return;
    }

    notifyListeners();
  }

  /// 1초 간격으로 도는 틱 사이에 벽시계가 크게 튀었다면 기기 시각이 바뀐 것이다.
  /// (앱이 백그라운드로 내려가 있는 동안은 틱이 안 돌므로 여기 걸리지 않는다)
  void _detectClockJump() {
    final now = DateTime.now();
    final last = _lastTickAt;
    _lastTickAt = now;
    if (last == null) return;

    // 백그라운드를 거쳤다면 공백이 큰 게 정상이다. 한 번 건너뛴다.
    if (_sawPauseSinceLastTick) {
      _sawPauseSinceLastTick = false;
      return;
    }

    final gap = now.difference(last);
    if (gap.isNegative || gap > const Duration(seconds: 90)) {
      _clockTampered = true;
    }
  }

  /// 경과·잔여 시간을 startedAt 기준으로 재계산한다.
  /// 앱 재개 시점에도 호출해 백그라운드 동안의 공백을 메운다.
  void syncElapsed() {
    final session = _currentSession;
    if (session == null) return;

    final target = session.targetMinutes * 60;
    final elapsed = DateTime.now().difference(session.startedAt).inSeconds;

    _elapsedSeconds = elapsed.clamp(0, target);
    _remainingSeconds = (target - _elapsedSeconds).clamp(0, target);

    // 복귀 직후 다음 틱이 정지 구간 전체를 점프로 오인하지 않도록 기준을 당겨둔다.
    _lastTickAt = DateTime.now();
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
    _monotonic.stop();

    if (_currentSession == null) return;

    // 기기 시각이 조작된 정황이 있으면 크레딧을 지급하지 않고 무효 처리한다.
    if (_clockTampered) {
      _isCompleting = false;
      await abandonSession(nopenalty: true);
      return;
    }

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
        description: '$actualMinutes분 집중 완료',
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
    _clockTampered = false;
    _sawPauseSinceLastTick = false;
    _lastTickAt = null;
    _monotonic
      ..stop()
      ..reset();
    _earnedCredits = 0;
    _earnedXp = 0;
    _newLevel = 0;
    _newBadges = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _monotonic.stop();
    super.dispose();
  }
}
