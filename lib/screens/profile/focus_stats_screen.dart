import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/focus_service.dart';
import '../../widgets/weekly_chart.dart';

class FocusStatsScreen extends StatefulWidget {
  const FocusStatsScreen({super.key});

  @override
  State<FocusStatsScreen> createState() => _FocusStatsScreenState();
}

class _FocusStatsScreenState extends State<FocusStatsScreen> {
  final FocusService _focusService = FocusService();
  List<int> _weeklyData = List.filled(7, 0);

  static const _dayOrder = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _loadWeeklyStats();
  }

  Future<void> _loadWeeklyStats() async {
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid == null) return;
    try {
      final stats = await _focusService.getWeeklyStats(uid);
      if (mounted) {
        setState(() {
          _weeklyData = _dayOrder.map((d) => stats[d] ?? 0).toList();
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final totalMinutes = user?.totalFocusMinutes ?? 0;
    final todayMinutes = user?.todayFocusMinutes ?? 0;
    final currentStreak = user?.currentStreak ?? 0;
    final longestStreak = user?.longestStreak ?? 0;
    final createdAt = user?.createdAt ?? DateTime.now();
    final daysSince = DateTime.now().difference(createdAt).inDays + 1;
    final avgDaily = daysSince > 0 ? totalMinutes ~/ daysSince : 0;

    return Scaffold(
      appBar: AppBar(title: const Text('집중 통계')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryRow(context, totalMinutes, todayMinutes),
            const SizedBox(height: 20),
            _buildStreakCard(context, currentStreak, longestStreak),
            const SizedBox(height: 20),
            _buildSectionTitle(context, '이번 주 집중'),
            const SizedBox(height: 12),
            WeeklyChart(data: _weeklyData),
            const SizedBox(height: 20),
            _buildBottomStats(context, daysSince, avgDaily),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
      BuildContext context, int totalMinutes, int todayMinutes) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: '총 집중 시간',
            value: '${totalMinutes ~/ 60}',
            unit: '시간',
            icon: Icons.timer,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: '오늘 집중',
            value: '$todayMinutes',
            unit: '분',
            icon: Icons.today,
            color: AppTheme.accentGreen,
          ),
        ),
      ],
    );
  }

  Widget _buildStreakCard(
      BuildContext context, int currentStreak, int longestStreak) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.of(context).card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.local_fire_department,
                    color: AppTheme.secondaryColor, size: 28),
                const SizedBox(height: 8),
                Text(
                  '$currentStreak일',
                  style: TextStyle(
                    color: AppTheme.secondaryColor,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '현재 연속',
                  style: TextStyle(color: AppTheme.of(context).textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 60,
            color: AppTheme.of(context).textSecondary.withAlpha(50),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.emoji_events,
                      color: AppTheme.creditGold, size: 28),
                  const SizedBox(height: 8),
                  Text(
                    '$longestStreak일',
                    style: const TextStyle(
                      color: AppTheme.creditGold,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '최장 연속',
                    style:
                        TextStyle(color: AppTheme.of(context).textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomStats(
      BuildContext context, int daysSince, int avgDaily) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: '이용 일수',
            value: '$daysSince',
            unit: '일',
            icon: Icons.calendar_today,
            color: AppTheme.primaryColor.withAlpha(200),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: '일평균 집중',
            value: '$avgDaily',
            unit: '분',
            icon: Icons.trending_up,
            color: AppTheme.accentGreen.withAlpha(200),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleLarge
          ?.copyWith(fontSize: 16),
    );
  }

}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.of(context).card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: color,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                    color: AppTheme.of(context).textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: AppTheme.of(context).textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
