import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/constants.dart';
import '../../design/ds.dart';
import '../../providers/auth_provider.dart';
import '../../services/focus_service.dart';
import '../../services/friend_service.dart';
import '../../widgets/common/ds_button.dart';
import '../social/friends_screen.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen>
    with SingleTickerProviderStateMixin {
  final FocusService _focusService = FocusService();
  final FriendService _friendService = FriendService();
  late TabController _tabController;
  String _period = 'weekly';

  late Future<List<Map<String, dynamic>>> _globalFuture;
  Future<List<Map<String, dynamic>>>? _friendFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _globalFuture = _focusService.getRanking(_period);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.index == 1) {
      _loadFriendRanking();
    }
  }

  void _loadFriendRanking() {
    final String myUid = context.read<AuthProvider>().user?.uid ?? '';
    setState(() {
      _friendFuture = _friendService
          .getFriendUids(myUid)
          .then((List<String> uids) =>
              _focusService.getFriendRanking(_period, uids, myUid));
    });
  }

  void _changePeriod(String period) {
    setState(() {
      _period = period;
      _globalFuture = _focusService.getRanking(period);
      if (_tabController.index == 1) {
        _friendFuture = null;
        _loadFriendRanking();
      }
    });
  }

  void _refresh() {
    setState(() {
      _globalFuture = _focusService.getRanking(_period);
      if (_tabController.index == 1) {
        _friendFuture = null;
        _loadFriendRanking();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    final String myUid = context.watch<AuthProvider>().user?.uid ?? '';

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: const Text('랭킹'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.people_outline),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                  builder: (_) => const FriendsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refresh,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom:
                    BorderSide(color: c.borderSubtle, width: Stroke.hairline),
              ),
            ),
            child: TabBar(
              controller: _tabController,
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
              tabs: const <Widget>[
                Tab(text: '전체'),
                Tab(text: '친구'),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x3, Sp.x4, 0),
            child: Row(
              children: <Widget>[
                _PeriodChip(
                  selected: _period == 'daily',
                  label: '일간',
                  onTap: () => _changePeriod('daily'),
                ),
                const SizedBox(width: Sp.x2),
                _PeriodChip(
                  selected: _period == 'weekly',
                  label: '주간',
                  onTap: () => _changePeriod('weekly'),
                ),
                const SizedBox(width: Sp.x2),
                _PeriodChip(
                  selected: _period == 'monthly',
                  label: '월간',
                  onTap: () => _changePeriod('monthly'),
                ),
              ],
            ),
          ),
          const SizedBox(height: Sp.x2),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: <Widget>[
                _RankingList(future: _globalFuture, myUid: myUid),
                _FriendRankingList(
                  future: _friendFuture,
                  myUid: myUid,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.standard,
        padding: const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x2),
        decoration: BoxDecoration(
          color: selected ? c.flame : c.surface,
          borderRadius: R.rSm,
          border: Border.all(
            color: selected ? c.flame : c.borderDefault,
            width: Stroke.hairline,
          ),
        ),
        child: Text(
          label,
          style: DsType.label.on(selected ? c.onAccent : c.textSecondary),
        ),
      ),
    );
  }
}

class _FriendRankingList extends StatelessWidget {
  const _FriendRankingList({required this.future, required this.myUid});

  final Future<List<Map<String, dynamic>>>? future;
  final String myUid;

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    if (future == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Sp.x8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.people_outline, size: 40, color: c.textTertiary),
              const SizedBox(height: Sp.x4),
              Text(
                '친구를 추가하면\n친구 랭킹을 볼 수 있어요',
                textAlign: TextAlign.center,
                style: DsType.body.on(c.textSecondary),
              ),
              const SizedBox(height: Sp.x4),
              SizedBox(
                width: 160,
                child: DsButton(
                  label: '친구 추가하기',
                  icon: Icons.person_add,
                  expand: true,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) => const FriendsScreen()),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return _RankingList(future: future!, myUid: myUid, isFriend: true);
  }
}

class _RankingList extends StatelessWidget {
  const _RankingList({
    required this.future,
    required this.myUid,
    this.isFriend = false,
  });

  final Future<List<Map<String, dynamic>>> future;
  final String myUid;
  final bool isFriend;

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (BuildContext context,
          AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: c.flame, strokeWidth: 2),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              '랭킹을 불러오지 못했어요\n잠시 후 다시 시도해주세요',
              textAlign: TextAlign.center,
              style: DsType.body.on(c.textSecondary),
            ),
          );
        }
        final List<Map<String, dynamic>> rankings = snapshot.data ?? [];
        if (rankings.isEmpty) {
          return Center(
            child: Text(
              isFriend ? '아직 친구가 없거나 집중 기록이 없어요.' : '아직 집중 기록이 없습니다.',
              style: DsType.body.on(c.textSecondary),
            ),
          );
        }

        final List<Map<String, dynamic>> top3 = rankings.take(3).toList();
        final List<Map<String, dynamic>> rest = rankings.skip(3).toList();

        return ListView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x2, Sp.x4, Sp.x6),
          children: <Widget>[
            if (top3.isNotEmpty) _Podium(top3: top3, myUid: myUid),
            const SizedBox(height: Sp.x4),
            ...rest.map((Map<String, dynamic> item) =>
                _RankItem(item: item, myUid: myUid)),
          ],
        );
      },
    );
  }
}

String _timeStr(int minutes) {
  final int h = minutes ~/ 60;
  final int m = minutes % 60;
  return h > 0 ? '$h시간${m > 0 ? ' $m분' : ''}' : '$m분';
}

class _Podium extends StatelessWidget {
  const _Podium({required this.top3, required this.myUid});

  final List<Map<String, dynamic>> top3;
  final String myUid;

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>?> items = <Map<String, dynamic>?>[
      top3.length > 1 ? top3[1] : null,
      top3.isNotEmpty ? top3[0] : null,
      top3.length > 2 ? top3[2] : null,
    ];
    const List<double> heights = <double>[72, 104, 56];
    const List<String> labels = <String>['2', '1', '3'];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List<Widget>.generate(3, (int i) {
        final Map<String, dynamic>? item = items[i];
        if (item == null) return const Expanded(child: SizedBox());
        return _PodiumItem(
          item: item,
          myUid: myUid,
          podiumHeight: heights[i],
          label: labels[i],
          first: i == 1,
        );
      }),
    );
  }
}

class _PodiumItem extends StatelessWidget {
  const _PodiumItem({
    required this.item,
    required this.myUid,
    required this.podiumHeight,
    required this.label,
    required this.first,
  });

  final Map<String, dynamic> item;
  final String myUid;
  final double podiumHeight;
  final String label;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    final String name = item['name'] as String? ?? '집중러';
    final int minutes = item['minutes'] as int? ?? 0;
    final int avatarIndex =
        ((item['avatarIndex'] as int?) ?? 0)
            .clamp(0, AppConstants.avatarEmojis.length - 1);
    final bool isMe = item['uid'] == myUid;

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: first ? c.flameTint : c.surface,
              border: Border.all(
                color: first || isMe ? c.flame : c.borderDefault,
                width: isMe ? Stroke.thick : Stroke.hairline,
              ),
            ),
            child: Center(
              child: Text(
                AppConstants.avatarEmojis[avatarIndex],
                style: const TextStyle(fontSize: 28),
              ),
            ),
          ),
          const SizedBox(height: Sp.x2),
          Text(
            name,
            style: DsType.caption.on(isMe ? c.accentText : c.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            _timeStr(minutes),
            style: DsType.caption.on(first ? c.accentText : c.textTertiary).tnum,
          ),
          const SizedBox(height: Sp.x2),
          Container(
            height: podiumHeight,
            margin: const EdgeInsets.symmetric(horizontal: Sp.x1),
            decoration: DsSurface.of(
              c,
              DsElevation.e1,
              radius: const BorderRadius.vertical(top: Radius.circular(R.sm)),
              tone: first ? c.flameTint : null,
              borderColor: first ? c.flame : null,
            ),
            child: Center(
              child: Text(
                label,
                style: DsType.subhead
                    .on(first ? c.accentText : c.textSecondary)
                    .tnum,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankItem extends StatelessWidget {
  const _RankItem({required this.item, required this.myUid});

  final Map<String, dynamic> item;
  final String myUid;

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    final int rank = item['rank'] as int? ?? 0;
    final String name = item['name'] as String? ?? '집중러';
    final int minutes = item['minutes'] as int? ?? 0;
    final int streak = item['streak'] as int? ?? 0;
    final int avatarIndex =
        ((item['avatarIndex'] as int?) ?? 0)
            .clamp(0, AppConstants.avatarEmojis.length - 1);
    final bool isMe = item['uid'] == myUid;

    return Container(
      margin: const EdgeInsets.only(bottom: Sp.x2),
      padding: const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x3),
      decoration: DsSurface.of(
        c,
        DsElevation.e1,
        tone: isMe ? c.flameTint : null,
        borderColor: isMe ? c.flame : null,
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 36,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: DsType.subhead
                  .on(isMe ? c.accentText : c.textTertiary)
                  .tnum,
            ),
          ),
          const SizedBox(width: Sp.x2),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.surface,
              border: Border.all(
                color: isMe ? c.flame : c.borderDefault,
                width: Stroke.hairline,
              ),
            ),
            child: Center(
              child: Text(
                AppConstants.avatarEmojis[avatarIndex],
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: Sp.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        name,
                        style: DsType.bodyStrong
                            .on(isMe ? c.accentText : c.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isMe) ...<Widget>[
                      const SizedBox(width: Sp.x2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: Sp.x2, vertical: 2),
                        decoration: DsSurface.tint(c, c.flame, radius: R.rSm),
                        child: Text('나', style: DsType.micro.on(c.onAccent)),
                      ),
                    ],
                  ],
                ),
                if (streak > 0)
                  Text(
                    '$streak일 연속',
                    style: DsType.caption.on(c.textTertiary).tnum,
                  ),
              ],
            ),
          ),
          Text(
            _timeStr(minutes),
            style: DsType.bodyStrong
                .on(isMe ? c.accentText : c.textPrimary)
                .tnum,
          ),
        ],
      ),
    );
  }
}
