import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design/ds.dart';
import '../../domain/goal_rules.dart';
import '../../providers/auth_provider.dart';
import '../../providers/goal_provider.dart';
import '../../services/focus_service.dart';
import '../../widgets/common/ds_pressable.dart';
import '../../widgets/weekly_chart.dart';
import 'records_shared.dart';

/// 통계 탭 — 오늘·누적·스트릭·주간, 그리고 하루 목표 설정.
class StatsTab extends StatefulWidget {
  const StatsTab({super.key});

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab>
    with AutomaticKeepAliveClientMixin {
  final FocusService _focusService = FocusService();
  List<int> _weekly = List<int>.filled(7, 0);
  bool _weeklyFailed = false;

  static const List<String> _dayOrder = <String>[
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadWeekly();
  }

  Future<void> _loadWeekly() async {
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid == null) return;
    try {
      final stats = await _focusService.getWeeklyStats(uid);
      if (!mounted) return;
      setState(() {
        _weekly = _dayOrder.map((d) => stats[d] ?? 0).toList();
        _weeklyFailed = false;
      });
    } catch (e) {
      debugPrint('주간 통계 로드 실패: $e');
      if (mounted) setState(() => _weeklyFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final DsColors c = context.ds;
    final user = context.watch<AuthProvider>().user;
    final goal = context.watch<GoalProvider>();

    final int totalMinutes = user?.totalFocusMinutes ?? 0;
    final int todayMinutes = user?.effectiveTodayFocusMinutes() ?? 0;
    final int currentStreak = user?.currentStreak ?? 0;
    final int longestStreak = user?.longestStreak ?? 0;
    final DateTime createdAt = user?.createdAt ?? DateTime.now();
    final int daysSince = DateTime.now().difference(createdAt).inDays + 1;
    final int avgDaily = daysSince > 0 ? totalMinutes ~/ daysSince : 0;
    final int weekTotal = _weekly.fold(0, (a, b) => a + b);

    return RefreshIndicator(
      color: c.flame,
      onRefresh: () async {
        await context.read<AuthProvider>().loadUser();
        await _loadWeekly();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x4, Sp.x4, Sp.x12),
        children: <Widget>[
          _GoalCard(
            todayMinutes: todayMinutes,
            goalMinutes: goal.dailyGoalMinutes,
            onIncrease: goal.increase,
            onDecrease: goal.decrease,
          ),
          const SizedBox(height: Sp.x4),
          Row(
            children: <Widget>[
              Expanded(
                child: RecordFact(
                  label: '오늘',
                  value: '$todayMinutes',
                  unit: '분',
                  accent: todayMinutes > 0,
                ),
              ),
              const SizedBox(width: Sp.x3),
              Expanded(
                child: RecordFact(
                  label: '누적',
                  value: '${totalMinutes ~/ 60}',
                  unit: '시간',
                ),
              ),
            ],
          ),
          const SizedBox(height: Sp.x3),
          Row(
            children: <Widget>[
              Expanded(
                child: RecordFact(
                  label: '현재 연속',
                  value: '$currentStreak',
                  unit: '일',
                ),
              ),
              const SizedBox(width: Sp.x3),
              Expanded(
                child: RecordFact(
                  label: '최장 연속',
                  value: '$longestStreak',
                  unit: '일',
                ),
              ),
            ],
          ),
          const SizedBox(height: Sp.x6),
          RecordSectionTitle(
            '이번 주',
            trailing: Text(
              _weeklyFailed ? '불러오지 못함' : formatMinutesKo(weekTotal),
              style: DsType.caption.on(c.textTertiary).tnum,
            ),
          ),
          WeeklyChart(data: _weekly),
          const SizedBox(height: Sp.x6),
          Row(
            children: <Widget>[
              Expanded(
                child: RecordFact(
                  label: '이용 일수',
                  value: '$daysSince',
                  unit: '일',
                ),
              ),
              const SizedBox(width: Sp.x3),
              Expanded(
                child: RecordFact(
                  label: '일평균',
                  value: '$avgDaily',
                  unit: '분',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 하루 목표. 홈 다이얼의 기준값이며 여기서만 바꾼다.
class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.todayMinutes,
    required this.goalMinutes,
    required this.onIncrease,
    required this.onDecrease,
  });

  final int todayMinutes;
  final int goalMinutes;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    final double progress =
        GoalRules.progress(todayMinutes: todayMinutes, goalMinutes: goalMinutes);
    final bool canDecrease = goalMinutes > GoalRules.minMinutes;
    final bool canIncrease = goalMinutes < GoalRules.maxMinutes;

    return Container(
      padding: Sp.card,
      decoration: DsSurface.e1(c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('하루 목표', style: DsType.caption.on(c.textTertiary)),
              Text(
                '${(progress * 100).round()}%',
                style: DsType.caption.on(c.textSecondary).tnum,
              ),
            ],
          ),
          const SizedBox(height: Sp.x2),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  GoalRules.label(goalMinutes),
                  style: DsType.title.on(c.textPrimary).tnum,
                ),
              ),
              _Stepper(
                icon: Icons.remove_rounded,
                enabled: canDecrease,
                onTap: onDecrease,
              ),
              const SizedBox(width: Sp.x2),
              _Stepper(
                icon: Icons.add_rounded,
                enabled: canIncrease,
                onTap: onIncrease,
              ),
            ],
          ),
          const SizedBox(height: Sp.x3),
          ClipRRect(
            borderRadius: R.rPill,
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: c.surfaceOverlay,
              valueColor: AlwaysStoppedAnimation<Color>(c.flame),
            ),
          ),
          const SizedBox(height: Sp.x2),
          Text(
            '오늘 ${formatMinutesKo(todayMinutes)} · ${GoalRules.stepMinutes}분 단위로 조정',
            style: DsType.micro.on(c.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    return DsPressable(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: c.surfaceRaised,
          borderRadius: R.rSm,
          border: Border.all(color: c.borderDefault, width: Stroke.hairline),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? c.textPrimary : c.textDisabled,
        ),
      ),
    );
  }
}
