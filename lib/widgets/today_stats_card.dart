import 'package:flutter/material.dart';
import '../config/theme.dart';

class TodayStatsCard extends StatelessWidget {
  final int focusMinutes;
  final int earnedCredits;
  final int streak;

  const TodayStatsCard({
    super.key,
    required this.focusMinutes,
    required this.earnedCredits,
    required this.streak,
  });

  String _getMotivationMessage() {
    if (focusMinutes == 0) return '오늘 집중을 시작해보세요!';
    if (focusMinutes < 30) return '좋은 시작이에요! 계속 해봐요 🔥';
    if (focusMinutes < 60) return '30분 돌파! 파이팅 💪';
    if (focusMinutes < 120) return '1시간 돌파! 대단해요 🚀';
    return '오늘도 열심히 집중했어요 🎉';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.of(context).card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.of(context).borderSubtle, width: 1),
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.08),
            AppTheme.of(context).card,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 18,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 10),
              Text('오늘의 현황',
                  style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  icon: Icons.timer_outlined,
                  value: focusMinutes < 60
                      ? '$focusMinutes분'
                      : '${focusMinutes ~/ 60}h ${focusMinutes % 60}m',
                  label: '집중 시간',
                  color: AppTheme.primaryColor,
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: AppTheme.of(context).borderSubtle,
              ),
              Expanded(
                child: _StatItem(
                  icon: Icons.toll_outlined,
                  value: '$earnedCredits',
                  label: '획득 크레딧',
                  color: AppTheme.creditGold,
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: AppTheme.of(context).borderSubtle,
              ),
              Expanded(
                child: _StatItem(
                  icon: Icons.local_fire_department_outlined,
                  value: '$streak일',
                  label: '연속 스트릭',
                  color: AppTheme.secondaryColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.of(context).bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _getMotivationMessage(),
              style: TextStyle(
                color: focusMinutes >= 120
                    ? AppTheme.accentGreen
                    : AppTheme.of(context).textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 17,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
          ),
        ),
        SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            color: AppTheme.of(context).textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
