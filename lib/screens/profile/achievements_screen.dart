import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final earnedIds = user?.badges ?? [];
    final earnedCount = AppConstants.badgeDefinitions
        .where((b) => earnedIds.contains(b['id']))
        .length;
    final total = AppConstants.badgeDefinitions.length;

    return Scaffold(
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (bounds) =>
              AppTheme.primaryGradient.createShader(bounds),
          child: const Text(
            '업적',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          _buildHeader(context, earnedCount, total),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.9,
              ),
              itemCount: AppConstants.badgeDefinitions.length,
              itemBuilder: (context, index) {
                final badge = AppConstants.badgeDefinitions[index];
                final earned = earnedIds.contains(badge['id']);
                return _BadgeCard(badge: badge, earned: earned);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int earned, int total) {
    final progress = total == 0 ? 0.0 : earned / total;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.of(context).card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.of(context).borderSubtle),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '획득한 배지',
                style: TextStyle(
                  color: AppTheme.of(context).textSecondary,
                  fontSize: 13,
                ),
              ),
              Text(
                '$earned / $total',
                style: TextStyle(
                  color: AppTheme.of(context).textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppTheme.of(context).surface,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppTheme.primaryColor,
              ),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final Map<String, dynamic> badge;
  final bool earned;

  const _BadgeCard({required this.badge, required this.earned});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showBadgeDetail(context),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.of(context).card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: earned
                ? AppTheme.primaryColor.withValues(alpha: 0.4)
                : AppTheme.of(context).borderSubtle,
            width: earned ? 1.5 : 1,
          ),
          boxShadow: earned
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Badge icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: earned
                    ? AppTheme.primaryColor.withValues(alpha: 0.12)
                    : AppTheme.of(context).surface,
                border: earned
                    ? Border.all(
                        color: AppTheme.primaryColor.withValues(alpha: 0.3),
                        width: 1.5,
                      )
                    : null,
              ),
              child: Center(
                child: ColorFiltered(
                  colorFilter: earned
                      ? const ColorFilter.mode(
                          Colors.transparent, BlendMode.multiply)
                      : const ColorFilter.matrix([
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0, 0, 0, 0.4, 0,
                        ]),
                  child: Text(
                    badge['icon'] as String,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              ),
            ),
            SizedBox(height: 10),
            Text(
              badge['name'] as String,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: earned ? AppTheme.of(context).textPrimary : AppTheme.of(context).textMuted,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            SizedBox(height: 4),
            Text(
              earned ? '획득 완료' : '미획득',
              style: TextStyle(
                color: earned ? AppTheme.primaryColor : AppTheme.of(context).textMuted,
                fontSize: 11,
                fontWeight: earned ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBadgeDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.of(context).textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            // Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: earned
                    ? AppTheme.primaryColor.withValues(alpha: 0.12)
                    : AppTheme.of(context).card,
                border: earned
                    ? Border.all(
                        color: AppTheme.primaryColor.withValues(alpha: 0.4),
                        width: 2,
                      )
                    : Border.all(color: AppTheme.of(context).borderSubtle),
                boxShadow: earned
                    ? [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.2),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  badge['icon'] as String,
                  style: TextStyle(
                    fontSize: 36,
                    color: earned ? null : Colors.grey,
                  ),
                ),
              ),
            ),
            SizedBox(height: 16),
            Text(
              badge['name'] as String,
              style: TextStyle(
                color: AppTheme.of(context).textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              badge['desc'] as String,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.of(context).textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: earned
                    ? AppTheme.primaryColor.withValues(alpha: 0.12)
                    : AppTheme.of(context).card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: earned
                      ? AppTheme.primaryColor.withValues(alpha: 0.4)
                      : AppTheme.of(context).borderSubtle,
                ),
              ),
              child: Text(
                earned ? '획득 완료' : '미획득',
                style: TextStyle(
                  color: earned ? AppTheme.primaryColor : AppTheme.of(context).textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
