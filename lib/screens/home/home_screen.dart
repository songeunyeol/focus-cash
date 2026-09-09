import 'dart:async';

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/routes.dart';
import '../../design/ds.dart';
import '../../domain/session_recovery.dart';
import '../../providers/auth_provider.dart';
import '../../providers/focus_provider.dart';
import '../../providers/goal_provider.dart';
import '../../services/analytics_service.dart';
import '../../services/focus_service.dart';
import '../../services/xp_service.dart';
import '../../widgets/common/common.dart';
import '../profile/profile_screen.dart';
import '../ranking/ranking_screen.dart';
import '../records/records_screen.dart';
import '../store/store_screen.dart';

/// 하단 네비게이션 셸.
///
/// 상점·랭킹·프로필은 각자 Scaffold 를 들고 있어 여기서 임베드된다.
/// (독립 라우트로도 등록돼 있으므로 두 진입 경로가 모두 살아있다)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final AuthProvider auth = context.read<AuthProvider>();
      await auth.loadUser();
      if (!mounted) return;
      final bool recovering = await _tryRecoverSession(auth);
      if (!mounted || recovering) return;
      _tryCheckIn(auth);
    });
  }

  /// 강제 종료로 남은 세션이 있으면 이어하기/완료/폐기를 판정한다.
  /// 복구 화면으로 넘어가면 true 를 돌려 출석 체크 스낵바가 겹치지 않게 한다.
  Future<bool> _tryRecoverSession(AuthProvider auth) async {
    final PersistedSession? saved = await FocusProvider.readPersistedSession();
    if (saved == null || !mounted) return false;
    if (saved.userId != auth.user?.uid) {
      await FocusProvider.discardPersistedSession();
      return false;
    }

    final RecoveryAction action = decideRecovery(
      startedAt: saved.startedAt,
      targetMinutes: saved.targetMinutes,
      now: DateTime.now(),
    );
    if (action == RecoveryAction.discard) {
      await FocusProvider.discardPersistedSession();
      return false;
    }

    final bool? go = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) => _RecoveryDialog(
        session: saved,
        action: action,
      ),
    );
    if (!mounted) return false;

    if (go != true) {
      await FocusProvider.discardPersistedSession();
      unawaited(AnalyticsService.instance.sessionRecovered('discard'));
      return false;
    }

    context.read<FocusProvider>().resumeFromPersisted(saved);
    unawaited(AnalyticsService.instance.sessionRecovered(action.name));
    Navigator.of(context).pushNamed(
      AppRoutes.focus,
      arguments: <String, dynamic>{
        'focusMinutes': saved.targetMinutes,
        'hardcoreMode': saved.hardcoreMode,
        'tag': saved.tag,
        'watchAdOnStart': false,
      },
    );
    return true;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<AuthProvider>().loadUser();
    }
  }

  Future<void> _tryCheckIn(AuthProvider auth) async {
    final String? userId = auth.user?.uid;
    if (userId == null) return;
    final int gained = await XpService.instance.checkIn(userId);
    if (!mounted || gained == 0) return;
    await auth.loadUser();
    if (!mounted) return;

    final DsColors c = context.ds;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '출석 +$gained XP · Lv.${auth.user?.level ?? 1}',
          style: DsType.body.on(c.textPrimary),
        ),
        backgroundColor: c.surfaceRaised,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: R.rSm),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: DsTheme.overlayStyleFor(Theme.of(context).brightness),
      child: Scaffold(
      body: SafeArea(
        child: PageTransitionSwitcher(
          duration: Motion.standard,
          transitionBuilder: (Widget child, Animation<double> primary,
                  Animation<double> secondary) =>
              FadeThroughTransition(
            animation: primary,
            secondaryAnimation: secondary,
            child: child,
          ),
          child: KeyedSubtree(
            key: ValueKey<int>(_currentIndex),
            child: _buildCurrentPage(),
          ),
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: c.bg,
          border: Border(
            top: BorderSide(color: c.borderSubtle, width: Stroke.hairline),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (int i) => setState(() => _currentIndex = i),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          selectedItemColor: c.flame,
          unselectedItemColor: c.textDisabled,
          selectedLabelStyle: DsType.label,
          unselectedLabelStyle: DsType.label,
          elevation: 0,
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home_rounded),
                label: '홈'),
            BottomNavigationBarItem(
                icon: Icon(Icons.storefront_outlined),
                activeIcon: Icon(Icons.storefront_rounded),
                label: '상점'),
            BottomNavigationBarItem(
                icon: Icon(Icons.leaderboard_outlined),
                activeIcon: Icon(Icons.leaderboard_rounded),
                label: '랭킹'),
            BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded),
                activeIcon: Icon(Icons.person_rounded),
                label: '프로필'),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildCurrentPage() => switch (_currentIndex) {
        0 => const _HomePage(),
        1 => const StoreScreen(),
        2 => const RankingScreen(),
        _ => const ProfileScreen(),
      };
}

/// 홈 — 한 화면 한 질문.
///
/// 이 화면의 유일한 임무는 "지금 집중할래?"를 묻는 것이다. 통계·기록·차트는
/// 답이 아니라 결과이므로 기록 화면이 맡는다. 그래서 여기엔 다이얼 하나,
/// 시작 버튼 하나, 그리고 요약 한 줄만 남는다.
class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    final user = auth.user;

    final int todayMinutes = user?.todayFocusMinutes ?? 0;
    // 하루 목표는 기록 > 통계 탭에서 바꾼다 (기기 로컬 저장).
    final int goal = context.watch<GoalProvider>().dailyGoalMinutes;
    final double progress = goal == 0 ? 0 : todayMinutes / goal;
    final bool notStarted = todayMinutes <= 0;

    return RefreshIndicator(
      onRefresh: auth.loadUser,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Sp.x4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const SizedBox(height: Sp.x4),
                      _Header(
                        name: user?.displayName.isNotEmpty == true
                            ? user!.displayName
                            : '집중러',
                        credits: user?.totalCredits ?? 0,
                      ),
                      Expanded(
                        child: _Stage(
                          progress: progress,
                          todayMinutes: todayMinutes,
                          goalMinutes: goal,
                          notStarted: notStarted,
                        ),
                      ),
                      DsButton(
                        label: '집중 시작',
                        onPressed: () => Navigator.of(context)
                            .pushNamed(AppRoutes.focusSetup),
                      ),
                      const SizedBox(height: Sp.x3),
                      _Footer(
                        streak: user?.currentStreak ?? 0,
                        userId: user?.uid,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.credits});

  final String name;
  final int credits;

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(name, style: DsType.caption.on(c.textTertiary)),
        // 잔액은 홈의 주제가 아니다. 상점에서 쓸 때 크게 보면 된다.
        Text(
          _thousands(credits),
          style: DsType.caption.on(c.textTertiary).tnum,
        ),
      ],
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage({
    required this.progress,
    required this.todayMinutes,
    required this.goalMinutes,
    required this.notStarted,
  });

  final double progress;
  final int todayMinutes;
  final int goalMinutes;
  final bool notStarted;

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    final int remain = (goalMinutes - todayMinutes).clamp(0, goalMinutes);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        DsDial(
          progress: progress,
          child: notStarted
              ? const DsMascotSlot()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '오늘 집중',
                      // 한글은 자간을 넓히면 오히려 읽기 나빠진다.
                      // micro 역할의 넓은 자간은 라틴 대문자 라벨에만 쓴다.
                      style: DsType.label.on(c.textTertiary),
                    ),
                    const SizedBox(height: Sp.x1),
                    _DurationText(minutes: todayMinutes),
                    const SizedBox(height: 2),
                    Text(
                      '목표 ${_hmKo(goalMinutes)}',
                      style: DsType.label.on(c.textTertiary).tnum,
                    ),
                  ],
                ),
        ),
        const SizedBox(height: Sp.x6),
        Text(
          notStarted
              ? '오늘은 아직 시작 전이에요'
              : remain > 0
                  ? '목표까지 ${_hmKo(remain)}'
                  : '오늘 목표를 채웠어요',
          style: DsType.body.on(c.textSecondary),
        ),
      ],
    );
  }

}

/// 집중 시간 표시.
///
/// `18:00` 같은 시계 표기는 오후 6시로 읽힌다. 지속 시간과 시각을 같은 형식으로
/// 쓰면 안 된다. 숫자는 크게, 단위는 작고 흐리게 붙여 지속 시간임을 형태로 말한다.
class _DurationText extends StatelessWidget {
  const _DurationText({required this.minutes});

  final int minutes;

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    final int h = minutes ~/ 60;
    final int m = minutes % 60;

    final TextStyle big =
        DsType.timerDisplay.on(c.textPrimary).copyWith(fontSize: 44);
    final TextStyle unit = DsType.heading
        .on(c.textTertiary)
        .copyWith(fontSize: 18, fontWeight: FontWeight.w500);

    // 정각이면 분을 생략한다. "18시간 0분" 의 0분은 군더더기다.
    final bool showMinutes = m > 0 || h == 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        if (h > 0) ...<Widget>[
          Text('$h', style: big),
          Text('시간', style: unit),
          if (showMinutes) const SizedBox(width: Sp.x2),
        ],
        if (showMinutes) ...<Widget>[
          Text('$m', style: big),
          Text('분', style: unit),
        ],
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.streak, required this.userId});

  final int streak;
  final String? userId;

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: Sp.x3),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: c.borderSubtle, width: Stroke.hairline),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          _Fact(label: '스트릭', value: '$streak일'),
          _WeekFact(userId: userId),
          DsPressable(
            onTap: () => AppRoutes.openRecords(context, RecordsTab.stats),
            child: Text('기록 →', style: DsType.caption.on(c.textTertiary)),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    return Row(
      children: <Widget>[
        Text(label, style: DsType.caption.on(c.textTertiary)),
        const SizedBox(width: Sp.x2),
        Text(value, style: DsType.caption.on(c.textSecondary).tnum),
      ],
    );
  }
}

/// 이번 주 합계. 홈에서 주간 차트를 지웠으므로 숫자 하나만 남긴다.
class _WeekFact extends StatefulWidget {
  const _WeekFact({required this.userId});

  final String? userId;

  @override
  State<_WeekFact> createState() => _WeekFactState();
}

class _WeekFactState extends State<_WeekFact> {
  final FocusService _service = FocusService();
  int? _minutes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_WeekFact oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) _load();
  }

  Future<void> _load() async {
    final String? id = widget.userId;
    if (id == null) return;
    try {
      final Map<String, int> stats = await _service.getWeeklyStats(id);
      if (!mounted) return;
      setState(() => _minutes = stats.values.fold<int>(0, (int a, int b) => a + b));
    } catch (e) {
      debugPrint('주간 합계 조회 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) =>
      _Fact(label: '이번 주', value: _minutes == null ? '—' : _hmKo(_minutes!));
}

/// 강제 종료된 세션 복구 안내.
///
/// 이어하기(목표 전)와 완료 처리(목표 후) 두 경우만 물어본다.
/// 폐기 판정은 대화 없이 조용히 지운다 — 24시간 지난 세션을 놓고 고민시킬 이유가 없다.
class _RecoveryDialog extends StatelessWidget {
  const _RecoveryDialog({required this.session, required this.action});

  final PersistedSession session;
  final RecoveryAction action;

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    final bool complete = action == RecoveryAction.complete;
    final int elapsed = DateTime.now()
        .difference(session.startedAt)
        .inMinutes
        .clamp(0, session.targetMinutes);

    return AlertDialog(
      backgroundColor: c.surfaceRaised,
      shape: const RoundedRectangleBorder(borderRadius: R.rLg),
      title: Text(
        complete ? '끝내지 못한 집중이 있어요' : '진행 중이던 집중이 있어요',
        style: DsType.heading.on(c.textPrimary),
      ),
      content: Text(
        complete
            ? '${_hmKo(session.targetMinutes)} 목표를 시간상 채웠어요. 완료로 기록하고 크레딧을 받을까요?'
            : '${_hmKo(session.targetMinutes)} 목표 중 ${_hmKo(elapsed)}이 지났어요. 이어서 할까요?',
        style: DsType.body.on(c.textSecondary),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('버리기', style: DsType.bodyStrong.on(c.textTertiary)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(complete ? '완료 처리' : '이어하기',
              style: DsType.bodyStrong.on(c.accentText)),
        ),
      ],
    );
  }
}

// ── 포맷터 ───────────────────────────────────────────────
String _hmKo(int minutes) {
  final int h = minutes ~/ 60;
  final int m = minutes % 60;
  if (h == 0) return '$m분';
  if (m == 0) return '$h시간';
  return '$h시간 $m분';
}

String _thousands(int n) {
  final String s = n.toString();
  final StringBuffer out = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
    out.write(s[i]);
  }
  return out.toString();
}
