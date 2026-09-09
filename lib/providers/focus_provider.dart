import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../config/constants.dart';
import '../domain/credit_rules.dart';
import '../domain/session_recovery.dart';
import '../models/focus_session.dart';
import '../services/analytics_service.dart';
import '../services/focus_service.dart';
import '../services/credit_service.dart';
import '../services/notification_service.dart';
import '../services/server_api.dart';
import '../services/xp_service.dart';

enum FocusState { idle, focusing, completed, abandoned }

class FocusProvider extends ChangeNotifier {
  FocusProvider({
    FocusService? focusService,
    CreditService? creditService,
    ServerApi? serverApi,
  })  : _focusService = focusService ?? FocusService(),
        _creditService = creditService ?? CreditService(),
        _serverApi = serverApi ?? ServerApi();

  final FocusService _focusService;
  final CreditService _creditService;
  final ServerApi _serverApi;

  /// 진행 중 세션의 로컬 저장 키. 프로세스가 죽어도 이것만 남는다.
  static const String kActiveSessionKey = 'active_focus_session';

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
  int _firstFocusBonus = 0;
  int _referralBonus = 0;
  int _lastPenalty = 0;
  SessionOutcome _outcome = SessionOutcome.empty;

  /// Firestore 문서가 있는 세션인지. 시작 시 네트워크 실패로 `local-` id 를 받은 세션은
  /// 서버가 모르는 세션이므로 어떤 서버 경로도 타지 않는다 (크레딧도 없다).
  bool get _isServerSession =>
      _currentSession != null && !_currentSession!.id.startsWith('local-');

  FocusState get state => _state;
  int get earnedXp => _outcome.xpGained + _outcome.badgeXpGained;
  int get newLevel => _outcome.leveledUp ? _outcome.newLevel : 0;
  List<String> get newBadges => List.unmodifiable(_outcome.newBadges);
  FocusSession? get currentSession => _currentSession;
  int get remainingSeconds => _remainingSeconds;
  int get elapsedSeconds => _elapsedSeconds;
  int get elapsedMinutes => _elapsedSeconds ~/ 60;
  bool get clockTampered => _clockTampered;

  /// 이번 완료로 받은 첫 집중 보너스 (0 이면 해당 없음)
  int get firstFocusBonus => _firstFocusBonus;

  /// 이번 완료로 받은 친구 초대 보너스 (서버 정산 모드에서만 채워진다. 0 이면 해당 없음)
  int get referralBonus => _referralBonus;

  /// 마지막 포기에서 차감된 하드코어 페널티 (0 이면 없음)
  int get lastPenalty => _lastPenalty;

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
      _currentSession = await _focusService
          .startSession(
            userId: userId,
            targetMinutes: targetMinutes,
            hardcoreMode: hardcoreMode,
            tag: tag,
            watchedStartAd: watchedStartAd,
          )
          .timeout(const Duration(seconds: 5));
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

    _beginTicking();
    unawaited(_persistActiveSession());
    unawaited(AnalyticsService.instance.sessionStart(
      targetMinutes: targetMinutes,
      mode: hardcoreMode,
      withAd: watchedStartAd,
    ));
  }

  /// 강제 종료 후 복구된 세션으로 재개한다. Firestore 문서는 이미 있으므로 새로 만들지 않는다.
  /// 경과 시간이 목표를 넘겼으면 첫 틱에서 바로 완료 처리된다.
  void resumeFromPersisted(PersistedSession p) {
    _currentSession = FocusSession(
      id: p.id,
      userId: p.userId,
      targetMinutes: p.targetMinutes,
      hardcoreMode: p.hardcoreMode,
      tag: p.tag,
      startedAt: p.startedAt,
    );
    _beginTicking();
    // 복귀 직후 첫 틱이 긴 공백을 시각 조작으로 오인하지 않게 한다.
    _sawPauseSinceLastTick = true;
  }

  void _beginTicking() {
    final session = _currentSession!;
    _remainingSeconds = session.targetMinutes * 60;
    _elapsedSeconds = 0;
    _clockTampered = false;
    _firstFocusBonus = 0;
    _referralBonus = 0;
    _lastPenalty = 0;
    _outcome = SessionOutcome.empty;
    _lastTickAt = DateTime.now();
    _monotonic
      ..reset()
      ..start();
    _state = FocusState.focusing;
    syncElapsed();
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

    // 서버 정산 모드에서는 서버 시각이 앵커다. 기기 시각을 바꿔도 settleSession 이
    // "목표 시간이 아직 지나지 않았다"로 거절하므로 클라이언트 휴리스틱은 필요 없다.
    // (오탐으로 정상 세션을 무효 처리하는 쪽이 더 큰 손해다)
    if (AppConfig.useServerSettlement && _isServerSession) return;

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

    final session = _currentSession;
    if (session == null) return;

    // 기기 시각이 조작된 정황이 있으면 크레딧을 지급하지 않고 무효 처리한다.
    if (_clockTampered) {
      _isCompleting = false;
      await abandonSession(nopenalty: true, reason: 'clock_tampered');
      return;
    }

    final actualMinutes = _elapsedSeconds ~/ 60;
    final credits = CreditRules.sessionCredits(
      focusMinutes: actualMinutes,
      hardcoreMode: session.hardcoreMode,
      watchedStartAd: session.watchedStartAd,
    );

    if (AppConfig.useServerSettlement && _isServerSession) {
      await _completeViaServer(session, actualMinutes);
      return;
    }

    try {
      final (updated, outcome) = await _focusService
          .endSession(
            session: session,
            actualMinutes: actualMinutes,
            creditsEarned: credits,
            completed: true,
          )
          .timeout(const Duration(seconds: 8));
      _currentSession = updated;
      _outcome = outcome;

      // 약관상 일일 한도(250)는 집중 크레딧에 적용된다. 실제 지급량이 표시값이다.
      _earnedCredits = await _creditService
          .addCredits(
            userId: session.userId,
            amount: credits,
            description: '$actualMinutes분 집중 완료',
            dailyCap: AppConstants.dailyCreditCap,
          )
          .timeout(const Duration(seconds: 5));

      if (outcome.isFirstEverSession) {
        _firstFocusBonus = await _maybeGiveFirstFocusBonus(session.userId);
      }
    } catch (e) {
      debugPrint('세션 정산 실패: $e');
      _earnedCredits = 0;
    }

    final completedUserId = session.userId;
    _state = FocusState.completed;
    notifyListeners();

    await _clearPersistedSession();

    // 백그라운드 작업 (UI 불필요) — reset() 후 null 참조 방지
    _maybeGiveReferralBonus(completedUserId);
    _updateNotifications(completedUserId, _earnedCredits, actualMinutes);
    unawaited(AnalyticsService.instance.sessionComplete(
      actualMinutes: actualMinutes,
      credits: _earnedCredits,
      mode: session.hardcoreMode,
    ));
  }

  /// 서버 정산 경로 (AppConfig.useServerSettlement). 서버가 경과 시간을 검증하고
  /// 크레딧·XP·스트릭·배지·첫 집중 보너스·초대 보너스를 한 번에 반영한다.
  /// 클라이언트는 결과를 보여주기만 한다. (초대 보너스 클라이언트 경로는 타지 않는다)
  Future<void> _completeViaServer(FocusSession session, int actualMinutes) async {
    try {
      final r = await _serverApi.settleSession(session.id);
      _earnedCredits = r.credits;
      _firstFocusBonus = r.firstFocusBonus;
      _referralBonus = r.referralBonus;
      _outcome = SessionOutcome(
        xpGained: r.xpGained,
        badgeXpGained: r.badgeXpGained,
        oldLevel: r.oldLevel,
        newLevel: r.newLevel,
        newBadges: r.newBadges,
        currentStreak: r.currentStreak,
        totalMinutesBefore: r.firstFocusBonus > 0 ? 0 : 1,
      );
      _currentSession = session.copyWith(
        actualMinutes: actualMinutes,
        creditsEarned: r.credits,
        completed: true,
        endedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('서버 정산 실패: $e');
      _earnedCredits = 0;
    }

    _state = FocusState.completed;
    notifyListeners();
    await _clearPersistedSession();
    _updateNotifications(session.userId, _earnedCredits, actualMinutes);
    unawaited(AnalyticsService.instance.sessionComplete(
      actualMinutes: actualMinutes,
      credits: _earnedCredits,
      mode: session.hardcoreMode,
    ));
  }

  /// 첫 집중 완료 보너스 (구 가입 보너스). 플래그를 먼저 세워 중복 지급을 막는다.
  Future<int> _maybeGiveFirstFocusBonus(String userId) async {
    try {
      final ref = FirebaseFirestore.instance.collection('users').doc(userId);
      final granted = await FirebaseFirestore.instance.runTransaction<bool>((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return false;
        if (snap.data()?['firstFocusBonusGiven'] == true) return false;
        tx.update(ref, {'firstFocusBonusGiven': true});
        return true;
      });
      if (!granted) return 0;
      return await _creditService.addCredits(
        userId: userId,
        amount: AppConstants.firstFocusBonus,
        description: '첫 집중 완료 보너스',
      );
    } catch (e) {
      debugPrint('첫 집중 보너스 지급 실패: $e');
      return 0;
    }
  }

  Future<void> _updateNotifications(
      String userId, int credits, int minutes) async {
    try {
      final streak = _outcome.currentStreak;
      // 오늘 집중 완료 → 오늘 밤 알림 취소 후 내일 밤으로 재스케줄 (Duolingo 스타일)
      await NotificationService.instance
          .rescheduleStreakReminderToTomorrow(currentStreak: streak);

      // 화면이 꺼져 있거나 다른 앱에 있는 채로 끝났으면 알림으로 알려준다.
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
        await NotificationService.instance
            .showFocusCompleted(minutes: minutes, credits: credits);
      }
    } catch (_) {}
  }

  /// 친구 초대 보너스 — 클라이언트 정산 경로 전용 (과도기).
  /// 서버 정산 모드에서는 settleSession 이 같은 트랜잭션에서 지급하므로 호출하지 않는다.
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

      await _creditService.addCredits(
        userId: userId,
        amount: AppConstants.referralBonus,
        description: '친구 초대 보너스',
      );
      await _creditService.addCredits(
        userId: invitedBy,
        amount: AppConstants.referralBonus,
        description: '친구 초대 보너스 (초대 성공)',
      );
      // 초대자 inviteCount + invite_3 배지. 이전에는 호출처가 없어 배지가 영원히 안 나왔다.
      await XpService.instance.onInviteSuccess(invitedBy);
    } catch (_) {}
  }

  Future<void> addStartAdBonus() async {
    final session = _currentSession;
    if (session == null) return;

    int granted = AppConstants.startAdBonus;
    try {
      if (AppConfig.useServerSettlement && _isServerSession) {
        granted = await _serverApi.grantAdBonus(session.id, 'start');
        _earnedCredits += granted;
        notifyListeners();
        return;
      }
      granted = await _creditService.addCredits(
        userId: session.userId,
        amount: AppConstants.startAdBonus,
        description: '시작 광고 시청 보너스',
        dailyCap: AppConstants.dailyCreditCap,
      );
    } catch (e) {
      debugPrint('시작 광고 보너스 실패: $e');
    }

    _earnedCredits += granted;
    notifyListeners();
  }

  Future<void> addEndAdBonus() async {
    final session = _currentSession;
    if (session == null) return;

    final bonus = CreditRules.endAdBonus(_earnedCredits);
    if (bonus <= 0) return;

    int granted = bonus;
    try {
      if (AppConfig.useServerSettlement && _isServerSession) {
        granted = await _serverApi.grantAdBonus(session.id, 'end');
        _earnedCredits += granted;
        notifyListeners();
        return;
      }
      granted = await _creditService.addCredits(
        userId: session.userId,
        amount: bonus,
        description: '종료 광고 시청 보너스',
        dailyCap: AppConstants.dailyCreditCap,
      );
    } catch (e) {
      debugPrint('종료 광고 보너스 실패: $e');
    }

    _earnedCredits += granted;
    notifyListeners();
  }

  Future<void> abandonSession({
    bool nopenalty = false,
    String reason = 'user',
  }) async {
    _timer?.cancel();

    final session = _currentSession;
    if (session == null) return;

    final actualMinutes = _elapsedSeconds ~/ 60;

    _state = FocusState.abandoned;
    notifyListeners();

    try {
      if (AppConfig.useServerSettlement && _isServerSession) {
        // 서버가 포기 표시 + 하드코어 페널티를 한 트랜잭션으로 처리한다.
        // nopenalty(시각 조작 등 클라이언트 판단)는 서버 모드에서 의미가 없다 — 서버 시각이 기준이다.
        final r = await _serverApi
            .abandonSession(session.id, reason: reason)
            .timeout(const Duration(seconds: 8));
        _lastPenalty = r.penalty;
        _currentSession = session.copyWith(
          actualMinutes: r.actualMinutes,
          completed: false,
          endedAt: DateTime.now(),
        );
      } else {
        final (updated, _) = await _focusService
            .endSession(
              session: session,
              actualMinutes: actualMinutes,
              creditsEarned: 0,
              completed: false,
            )
            .timeout(const Duration(seconds: 5));
        _currentSession = updated;

        if (!nopenalty && session.hardcoreMode == 'hardcore') {
          _lastPenalty = await _creditService
              .applyPenalty(
                userId: session.userId,
                penaltyRate: AppConstants.hardcorePenaltyRate,
              )
              .timeout(const Duration(seconds: 5));
        }
      }
    } catch (e) {
      debugPrint('세션 포기 기록 실패: $e');
    }

    _earnedCredits = 0;
    await _clearPersistedSession();
    unawaited(AnalyticsService.instance.sessionAbandon(
      elapsedMinutes: actualMinutes,
      mode: session.hardcoreMode,
      reason: reason,
    ));
  }

  // ── 로컬 영속화 ─────────────────────────────────────────

  Future<void> _persistActiveSession() async {
    final s = _currentSession;
    if (s == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        kActiveSessionKey,
        PersistedSession(
          id: s.id,
          userId: s.userId,
          startedAt: s.startedAt,
          targetMinutes: s.targetMinutes,
          hardcoreMode: s.hardcoreMode,
          tag: s.tag,
        ).encode(),
      );
    } catch (e) {
      debugPrint('세션 저장 실패: $e');
    }
  }

  Future<void> _clearPersistedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(kActiveSessionKey);
    } catch (_) {}
  }

  /// 앱 시작 시 남아 있는 세션을 읽는다. 없거나 깨졌으면 null.
  static Future<PersistedSession?> readPersistedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return PersistedSession.tryParse(prefs.getString(kActiveSessionKey));
    } catch (_) {
      return null;
    }
  }

  /// 복구를 포기할 때. Firestore 문서는 cleanupOrphanedSessions 가 정리한다.
  static Future<void> discardPersistedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(kActiveSessionKey);
    } catch (_) {}
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
    _firstFocusBonus = 0;
    _referralBonus = 0;
    _lastPenalty = 0;
    _outcome = SessionOutcome.empty;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _monotonic.stop();
    super.dispose();
  }
}
