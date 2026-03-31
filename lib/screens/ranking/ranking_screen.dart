import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/focus_service.dart';
import '../../services/friend_service.dart';
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
    final myUid = context.read<AuthProvider>().user?.uid ?? '';
    setState(() {
      _friendFuture = _friendService
          .getFriendUids(myUid)
          .then((uids) => _focusService.getFriendRanking(_period, uids, myUid));
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
    final myUid = context.watch<AuthProvider>().user?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (bounds) =>
              AppTheme.primaryGradient.createShader(bounds),
          child: const Text(
            '랭킹',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.people_outline, color: AppTheme.of(context).textSecondary),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FriendsScreen()),
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: AppTheme.of(context).textSecondary),
            onPressed: _refresh,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.primaryColor,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: AppTheme.of(context).textSecondary,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            tabs: const [
              Tab(icon: Icon(Icons.public_outlined, size: 18), text: '전체 랭킹'),
              Tab(icon: Icon(Icons.group_outlined, size: 18), text: '친구 랭킹'),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // 기간 선택
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                _buildPeriodChip('daily', '일간'),
                const SizedBox(width: 8),
                _buildPeriodChip('weekly', '주간'),
                const SizedBox(width: 8),
                _buildPeriodChip('monthly', '월간'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRankingList(_globalFuture, myUid),
                _buildFriendRankingList(myUid),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendRankingList(String myUid) {
    if (_friendFuture == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.of(context).surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.of(context).borderSubtle),
              ),
              child: Icon(Icons.people_outline,
                  size: 40, color: AppTheme.of(context).textMuted),
            ),
            const SizedBox(height: 20),
            Text(
              '친구를 추가하면\n친구 랭킹을 볼 수 있어요!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.of(context).textSecondary,
                fontSize: 15,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: AppTheme.glowButton,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FriendsScreen()),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                ),
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('친구 추가하기'),
              ),
            ),
          ],
        ),
      );
    }
    return _buildRankingList(_friendFuture!, myUid, isFriend: true);
  }

  Widget _buildRankingList(
    Future<List<Map<String, dynamic>>> future,
    String myUid, {
    bool isFriend = false,
  }) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryColor),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off_rounded, color: AppTheme.of(context).textMuted, size: 40),
                const SizedBox(height: 12),
                Text(
                  '랭킹을 불러오지 못했어요\n잠시 후 다시 시도해주세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.of(context).textSecondary, height: 1.6),
                ),
              ],
            ),
          );
        }
        final rankings = snapshot.data ?? [];
        if (rankings.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer_outlined,
                    size: 48, color: AppTheme.of(context).textMuted),
                const SizedBox(height: 12),
                Text(
                  isFriend
                      ? '아직 친구가 없거나 집중 기록이 없어요.'
                      : '아직 집중 기록이 없습니다.',
                  style: TextStyle(color: AppTheme.of(context).textSecondary),
                ),
              ],
            ),
          );
        }

        // 상위 3명 포디움 + 나머지 리스트
        final top3 = rankings.take(3).toList();
        final rest = rankings.skip(3).toList();

        return ListView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (top3.isNotEmpty) _buildPodium(top3, myUid),
            const SizedBox(height: 16),
            ...rest.map((item) => _buildRankItem(item, myUid)),
          ],
        );
      },
    );
  }

  Widget _buildPodium(List<Map<String, dynamic>> top3, String myUid) {
    // 포디움 순서: 2위 - 1위 - 3위
    final items = <Map<String, dynamic>?>[];
    items.add(top3.length > 1 ? top3[1] : null); // 2위
    items.add(top3.isNotEmpty ? top3[0] : null);  // 1위
    items.add(top3.length > 2 ? top3[2] : null);  // 3위

    final heights = [90.0, 120.0, 70.0]; // 포디움 높이
    final colors = [AppTheme.rankSilver, AppTheme.rankGold, AppTheme.rankBronze];
    final labels = ['2위', '1위', '3위'];
    final medals = ['🥈', '🥇', '🥉'];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (i) {
        final item = items[i];
        if (item == null) return const Expanded(child: SizedBox());
        return _buildPodiumItem(
          item: item,
          myUid: myUid,
          podiumHeight: heights[i],
          rankColor: colors[i],
          label: labels[i],
          medal: medals[i],
        );
      }),
    );
  }

  Widget _buildPodiumItem({
    required Map<String, dynamic> item,
    required String myUid,
    required double podiumHeight,
    required Color rankColor,
    required String label,
    required String medal,
  }) {
    final name = item['name'] as String? ?? '집중러';
    final minutes = item['minutes'] as int? ?? 0;
    final avatarIndex =
        ((item['avatarIndex'] as int?) ?? 0).clamp(0, AppConstants.avatarEmojis.length - 1);
    final isMe = item['uid'] == myUid;

    final h = minutes ~/ 60;
    final m = minutes % 60;
    final timeStr = h > 0 ? '$h시간${m > 0 ? ' $m분' : ''}' : '$m분';

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 아바타
          Stack(
            alignment: Alignment.topCenter,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: rankColor.withValues(alpha: 0.15),
                  border: Border.all(
                    color: rankColor.withValues(alpha: isMe ? 1.0 : 0.6),
                    width: isMe ? 2.5 : 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: rankColor.withValues(alpha: 0.3),
                      blurRadius: 12,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    AppConstants.avatarEmojis[avatarIndex],
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              ),
              // 메달 뱃지
              Positioned(
                top: -6,
                child: Text(medal, style: const TextStyle(fontSize: 18)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: TextStyle(
              color: isMe ? AppTheme.primaryColor : AppTheme.of(context).textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            timeStr,
            style: TextStyle(
              color: rankColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          // 포디움 단
          Container(
            height: podiumHeight,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  rankColor.withValues(alpha: 0.3),
                  rankColor.withValues(alpha: 0.1),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
              border: Border(
                top: BorderSide(color: rankColor.withValues(alpha: 0.5), width: 1.5),
                left: BorderSide(color: rankColor.withValues(alpha: 0.2), width: 1),
                right: BorderSide(color: rankColor.withValues(alpha: 0.2), width: 1),
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: rankColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(String period, String label) {
    final isSelected = _period == period;
    return GestureDetector(
      onTap: () => _changePeriod(period),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected ? AppTheme.primaryGradient : null,
          color: isSelected ? null : AppTheme.of(context).surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : AppTheme.of(context).borderMid,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 0,
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.of(context).textSecondary,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildRankItem(Map<String, dynamic> item, String myUid) {
    final rank = item['rank'] as int? ?? 0;
    final name = item['name'] as String? ?? '집중러';
    final minutes = item['minutes'] as int? ?? 0;
    final streak = item['streak'] as int? ?? 0;
    final avatarIndex =
        ((item['avatarIndex'] as int?) ?? 0).clamp(0, AppConstants.avatarEmojis.length - 1);
    final isMe = item['uid'] == myUid;

    final h = minutes ~/ 60;
    final m = minutes % 60;
    final timeStr = h > 0 ? '$h시간${m > 0 ? ' $m분' : ''}' : '$m분';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isMe
            ? AppTheme.primaryColor.withValues(alpha: 0.08)
            : AppTheme.of(context).card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMe
              ? AppTheme.primaryColor.withValues(alpha: 0.4)
              : AppTheme.of(context).borderSubtle,
          width: isMe ? 1.5 : 1,
        ),
        boxShadow: isMe
            ? [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  blurRadius: 12,
                  spreadRadius: 0,
                )
              ]
            : null,
      ),
      child: Row(
        children: [
          // 순위 번호
          SizedBox(
            width: 36,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isMe ? AppTheme.primaryColor : AppTheme.of(context).textMuted,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // 아바타
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.of(context).surface,
              border: Border.all(
                color: isMe
                    ? AppTheme.primaryColor.withValues(alpha: 0.5)
                    : AppTheme.of(context).borderMid,
              ),
            ),
            child: Center(
              child: Text(
                AppConstants.avatarEmojis[avatarIndex],
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 이름 + 스트릭
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: isMe
                            ? AppTheme.primaryColor
                            : AppTheme.of(context).textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '나',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (streak > 0) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department,
                          size: 12, color: AppTheme.secondaryColor),
                      const SizedBox(width: 2),
                      Text(
                        '$streak일 연속',
                        style: TextStyle(
                          color: AppTheme.of(context).textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // 집중 시간
          Text(
            timeStr,
            style: TextStyle(
              color: isMe ? AppTheme.primaryColor : AppTheme.of(context).textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
