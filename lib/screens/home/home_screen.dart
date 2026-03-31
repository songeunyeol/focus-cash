import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';
import '../../services/xp_service.dart';
import '../../widgets/credit_display.dart';
import '../../widgets/today_stats_card.dart';
import '../../widgets/quick_start_button.dart';
import '../../widgets/weekly_chart.dart';
import '../../services/focus_service.dart';
import '../../models/focus_session.dart';
import '../store/store_screen.dart';
import '../ranking/ranking_screen.dart';
import '../profile/profile_screen.dart';

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
      final auth = context.read<AuthProvider>();
      await auth.loadUser();
      if (!mounted) return;
      _tryCheckIn(auth);
    });
  }

  Future<void> _tryCheckIn(AuthProvider auth) async {
    final userId = auth.user?.uid;
    if (userId == null) return;
    final gained = await XpService.instance.checkIn(userId);
    if (!mounted || gained == 0) return;
    await auth.loadUser();
    if (!mounted) return;
    final newLevel = auth.user?.level ?? 1;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.star_rounded, color: AppTheme.creditGold, size: 18),
            const SizedBox(width: 8),
            Text(
              '출석 체크! +$gained XP (Lv.$newLevel)',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: AppTheme.of(context).surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: [
            _buildHomePage(),
            _buildStorePage(),
            _buildRankingPage(),
            _buildProfilePage(),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.of(context).surface,
          border: Border(
            top: BorderSide(color: AppTheme.of(context).borderSubtle, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppTheme.of(context).surface,
          selectedItemColor: AppTheme.primaryColor,
          unselectedItemColor: AppTheme.of(context).textMuted,
          selectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          elevation: 0,
          items: const [
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
    );
  }

  Widget _buildHomePage() {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    return RefreshIndicator(
      onRefresh: () => authProvider.loadUser(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getGreeting(),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.displayName.isNotEmpty == true
                          ? user!.displayName
                          : '집중러',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ],
                ),
                CreditDisplay(credits: user?.totalCredits ?? 0),
              ],
            ),
            const SizedBox(height: 24),
            if ((user?.currentStreak ?? 0) >= 3)
              _buildStreakBanner(user!.currentStreak),
            if ((user?.currentStreak ?? 0) >= 3)
              const SizedBox(height: 16),
            TodayStatsCard(
              focusMinutes: user?.todayFocusMinutes ?? 0,
              earnedCredits: user?.todayCredits ?? 0,
              streak: user?.currentStreak ?? 0,
            ),
            const SizedBox(height: 24),
            QuickStartButton(
              onTap: () =>
                  Navigator.of(context).pushNamed(AppRoutes.focusSetup),
            ),
            const SizedBox(height: 24),
            // 최근 집중 기록
            if (user != null) ...[
              Text(
                '최근 집중 기록',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              _RecentSessionsList(userId: user.uid),
              const SizedBox(height: 24),
            ],

            Text(
              '이번 주 집중 현황',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (user != null)
              _WeeklyChartSection(
                key: ValueKey(user.totalFocusMinutes),
                userId: user.uid,
              )
            else
              WeeklyChart(data: List.filled(7, 0)),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakBanner(int streak) {
    final String emoji;
    final String message;
    final List<Color> colors;

    if (streak >= 30) {
      emoji = '👑';
      message = '$streak일 연속! 전설의 집중러!';
      colors = [const Color(0xFFB8860B), const Color(0xFFFFD700)];
    } else if (streak >= 14) {
      emoji = '🏆';
      message = '$streak일 연속! 대단해요!';
      colors = [const Color(0xFF7C3AED), const Color(0xFF9D5CF6)];
    } else if (streak >= 7) {
      emoji = '🔥';
      message = '$streak일 연속 집중 중!';
      colors = [const Color(0xFFDC2626), const Color(0xFFEA580C)];
    } else {
      emoji = '⚡';
      message = '$streak일 연속! 이어가요!';
      colors = [const Color(0xFF059669), const Color(0xFF34D399)];
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const Text(
                  '오늘도 집중해서 스트릭을 이어가세요!',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return '좋은 아침이에요! ☀️';
    if (hour >= 12 && hour < 14) return '점심 먹고 집중해요! 🍚';
    if (hour >= 14 && hour < 18) return '오후도 파이팅! 💪';
    if (hour >= 18 && hour < 22) return '저녁에도 집중! 🌙';
    return '오늘 하루 수고했어요! 🌟';
  }

  Widget _buildStorePage() {
    return const StoreScreen();
  }

  Widget _buildRankingPage() {
    return const RankingScreen();
  }

  Widget _buildProfilePage() {
    return const ProfileScreen();
  }
}

// ───────────────────────────────────────────
// 최근 집중 기록 위젯
// ───────────────────────────────────────────
class _RecentSessionsList extends StatelessWidget {
  final String userId;
  final _service = FocusService();

  _RecentSessionsList({required this.userId});

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${dt.month}/${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FocusSession>>(
      future: _service.getUserSessions(userId, limit: 3),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
                strokeWidth: 2,
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          debugPrint('최근 세션 로드 오류: ${snapshot.error}');
          return const SizedBox.shrink();
        }

        final sessions = snapshot.data ?? [];

        if (sessions.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.of(context).card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.of(context).textSecondary, size: 20),
                const SizedBox(width: 12),
                Text(
                  '아직 집중 기록이 없어요. 첫 세션을 시작해보세요!',
                  style: TextStyle(color: AppTheme.of(context).textSecondary, fontSize: 13),
                ),
              ],
            ),
          );
        }

        return Column(
          children: sessions.map((s) => _SessionItem(session: s, timeAgo: _timeAgo(s.startedAt))).toList(),
        );
      },
    );
  }
}

class _SessionItem extends StatelessWidget {
  final FocusSession session;
  final String timeAgo;

  const _SessionItem({required this.session, required this.timeAgo});

  @override
  Widget build(BuildContext context) {
    final isCompleted = session.completed;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.of(context).card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCompleted
              ? AppTheme.accentGreen.withValues(alpha: 0.3)
              : AppTheme.accentRed.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // 완료/포기 아이콘
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isCompleted
                  ? AppTheme.accentGreen.withValues(alpha: 0.15)
                  : AppTheme.accentRed.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCompleted ? Icons.check_circle : Icons.cancel,
              color: isCompleted ? AppTheme.accentGreen : AppTheme.accentRed,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),

          // 세션 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCompleted ? '집중 완료' : '세션 포기',
                  style: TextStyle(
                    color: isCompleted ? AppTheme.of(context).textPrimary : AppTheme.of(context).textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${session.actualMinutes}분 집중 · $timeAgo',
                  style: TextStyle(
                    color: AppTheme.of(context).textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // 크레딧
          if (isCompleted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.creditGold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '+${session.creditsEarned}',
                style: const TextStyle(
                  color: AppTheme.creditGold,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────
// 주간 차트 위젯
// ───────────────────────────────────────────
class _WeeklyChartSection extends StatelessWidget {
  final String userId;
  final _service = FocusService();

  _WeeklyChartSection({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, int>>(
      future: _service.getWeeklyStats(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 200,
            child: Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
                strokeWidth: 2,
              ),
            ),
          );
        }

        final raw = snapshot.data ?? {};
        final dayKeys = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final data = dayKeys.map((k) => raw[k] ?? 0).toList();

        return WeeklyChart(data: data);
      },
    );
  }
}
