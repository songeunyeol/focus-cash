import 'package:flutter/material.dart';

import '../../design/ds.dart';
import 'achievements_tab.dart';
import 'calendar_tab.dart';
import 'credits_tab.dart';
import 'stats_tab.dart';

/// 기록 화면의 탭. 라우트 인자로 초기 탭을 넘길 때 쓴다.
enum RecordsTab { stats, calendar, credits, achievements }

/// 기록 — 통계·캘린더·크레딧 내역·업적을 한 화면의 탭으로 묶는다.
///
/// 이전에는 프로필 화면에서 네 개의 별도 화면으로 흩어져 있었다.
/// 전부 "내가 한 것을 되돌아보는" 화면이라 한 곳에 두고, 위계는 탭이 진다.
/// 계기(Instrument) 모드: 액센트는 오늘 값과 진행 표시에만 쓴다.
class RecordsScreen extends StatelessWidget {
  const RecordsScreen({super.key, this.initialTab = RecordsTab.stats});

  final RecordsTab initialTab;

  static const List<(RecordsTab, String)> _tabs = <(RecordsTab, String)>[
    (RecordsTab.stats, '통계'),
    (RecordsTab.calendar, '캘린더'),
    (RecordsTab.credits, '크레딧'),
    (RecordsTab.achievements, '업적'),
  ];

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;

    return DefaultTabController(
      length: _tabs.length,
      initialIndex: initialTab.index,
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          title: const Text('기록'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(44),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                      color: c.borderSubtle, width: Stroke.hairline),
                ),
              ),
              child: TabBar(
                labelStyle: DsType.label,
                unselectedLabelStyle: DsType.label,
                labelColor: c.textPrimary,
                unselectedLabelColor: c.textTertiary,
                indicatorColor: c.flame,
                indicatorSize: TabBarIndicatorSize.label,
                indicatorWeight: Stroke.thick,
                dividerColor: Colors.transparent,
                splashFactory: NoSplash.splashFactory,
                overlayColor:
                    const WidgetStatePropertyAll<Color>(Colors.transparent),
                tabs: _tabs.map((t) => Tab(text: t.$2)).toList(),
              ),
            ),
          ),
        ),
        body: const TabBarView(
          children: <Widget>[
            StatsTab(),
            CalendarTab(),
            CreditsTab(),
            AchievementsTab(),
          ],
        ),
      ),
    );
  }
}
