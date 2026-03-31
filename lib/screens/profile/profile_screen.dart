import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/level_frame.dart';
import '../auth/signup_terms_screen.dart';
import '../social/friends_screen.dart';
import 'focus_stats_screen.dart';
import 'credit_history_screen.dart';
import 'my_gifticons_screen.dart';
import 'achievements_screen.dart';
import 'focus_calendar_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (bounds) =>
              AppTheme.primaryGradient.createShader(bounds),
          child: const Text(
            '프로필',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildAvatarSection(context, user),
            const SizedBox(height: 28),
            _buildStatsGrid(context, user),
            const SizedBox(height: 28),
            _buildSettingsSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarSection(BuildContext context, dynamic user) {
    final avatarIndex = (user?.avatarIndex ?? 0) as int;
    final emoji = AppConstants.avatarEmojis[
        avatarIndex.clamp(0, AppConstants.avatarEmojis.length - 1)];
    final level = user?.level ?? 1;
    final xp = user?.xp ?? 0;
    final currentLevelXp = AppConstants.xpForLevel(level);
    final nextLevelXp = AppConstants.xpForLevel(level + 1);
    final xpNeeded = nextLevelXp - currentLevelXp;
    final xpInLevel = (xp - currentLevelXp).clamp(0, xpNeeded);
    final xpProgress = xpNeeded > 0 ? (xpInLevel / xpNeeded).clamp(0.0, 1.0) : 1.0;

    return Column(
      children: [
        GestureDetector(
          onTap: () => _showAvatarPicker(context, user),
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              LevelFrame(
                level: level,
                size: 108,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.primaryGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 48)),
                  ),
                ),
              ),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppTheme.of(context).elevated,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: const Icon(Icons.edit_rounded,
                    size: 15, color: AppTheme.primaryColor),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        LevelBadge(level: level),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              user?.displayName.isNotEmpty == true
                  ? user!.displayName
                  : '집중러',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showNameEditDialog(context, user),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.of(context).surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.of(context).borderMid),
                ),
                child: Icon(Icons.edit_rounded,
                    size: 14, color: AppTheme.of(context).textSecondary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // XP progress bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.of(context).card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.of(context).borderSubtle),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Lv.$level → Lv.${level + 1}',
                    style: TextStyle(
                      color: AppTheme.of(context).textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '$xpInLevel / $xpNeeded XP',
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: xpProgress,
                  backgroundColor: AppTheme.of(context).surface,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.primaryColor,
                  ),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
        if (user?.phoneNumber.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.of(context).surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.of(context).borderSubtle),
            ),
            child: Text(
              user!.phoneNumber,
              style: TextStyle(
                color: AppTheme.of(context).textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showAvatarPicker(BuildContext context, dynamic user) {
    final authProvider = context.read<AuthProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
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
              const SizedBox(height: 20),
              Text('아바타 선택',
                  style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 20),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                itemCount: AppConstants.avatarEmojis.length,
                itemBuilder: (_, i) {
                  final selected = (user?.avatarIndex ?? 0) == i;
                  return GestureDetector(
                    onTap: () {
                      if (user != null) {
                        authProvider.updateAndSaveUser(
                          user.copyWith(avatarIndex: i),
                        );
                      }
                      Navigator.pop(ctx);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        gradient: selected ? AppTheme.primaryGradient : null,
                        color: selected ? null : AppTheme.of(ctx).card,
                        borderRadius: BorderRadius.circular(14),
                        border: selected
                            ? null
                            : Border.all(color: AppTheme.of(ctx).borderSubtle),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: AppTheme.primaryColor
                                      .withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  spreadRadius: 0,
                                )
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          AppConstants.avatarEmojis[i],
                          style: const TextStyle(fontSize: 32),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showNameEditDialog(BuildContext context, dynamic user) {
    final controller = TextEditingController(
      text: user?.displayName.isNotEmpty == true ? user!.displayName : '',
    );
    final authProvider = context.read<AuthProvider>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.of(context).card,
        title: Text('이름 수정',
            style: TextStyle(color: AppTheme.of(context).textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 10,
          style: TextStyle(color: AppTheme.of(context).textPrimary),
          decoration: InputDecoration(
            hintText: '새 이름 입력 (최대 10자)',
            hintStyle: TextStyle(color: AppTheme.of(context).textSecondary),
            counterStyle: TextStyle(color: AppTheme.of(context).textSecondary),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.of(context).textSecondary),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.primaryColor),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('취소',
                style: TextStyle(color: AppTheme.of(context).textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && user != null) {
                authProvider
                    .updateAndSaveUser(user.copyWith(displayName: newName));
              }
              Navigator.pop(ctx);
            },
            child: const Text('확인',
                style: TextStyle(color: AppTheme.primaryColor)),
          ),
        ],
      ),
    );
  }

  String _formatMinutes(int totalMinutes) {
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (h == 0) return '$m분';
    if (m == 0) return '$h시간';
    return '$h시간 $m분';
  }

  Widget _buildStatsGrid(BuildContext context, dynamic user) {
    final stats = [
      {
        'label': '총 집중 시간',
        'value': _formatMinutes(user?.totalFocusMinutes ?? 0),
        'icon': Icons.timer_rounded,
        'color': AppTheme.primaryColor,
      },
      {
        'label': '보유 크레딧',
        'value': '${user?.totalCredits ?? 0}',
        'icon': Icons.monetization_on_rounded,
        'color': AppTheme.creditGold,
      },
      {
        'label': '연속 스트릭',
        'value': '${user?.currentStreak ?? 0}일',
        'icon': Icons.local_fire_department_rounded,
        'color': AppTheme.secondaryColor,
      },
      {
        'label': '최장 스트릭',
        'value': '${user?.longestStreak ?? 0}일',
        'icon': Icons.emoji_events_rounded,
        'color': AppTheme.accentGreen,
      },
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.of(context).card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.of(context).borderSubtle),
      ),
      child: Row(
        children: List.generate(stats.length * 2 - 1, (i) {
          if (i.isOdd) {
            return Container(
              width: 1,
              height: 36,
              color: AppTheme.of(context).borderSubtle,
            );
          }
          final stat = stats[i ~/ 2];
          final color = stat['color'] as Color;
          return Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(stat['icon'] as IconData, color: color, size: 18),
                const SizedBox(height: 6),
                Text(
                  stat['value'] as String,
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  stat['label'] as String,
                  style: TextStyle(
                    color: AppTheme.of(context).textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context) {
    final quickItems = [
      {
        'icon': Icons.emoji_events_rounded,
        'title': '업적',
        'color': AppTheme.creditGold,
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AchievementsScreen()),
            ),
      },
      {
        'icon': Icons.calendar_month_rounded,
        'title': '집중 캘린더',
        'color': AppTheme.primaryColor,
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FocusCalendarScreen()),
            ),
      },
      {
        'icon': Icons.people_rounded,
        'title': '친구',
        'color': AppTheme.secondaryColor,
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FriendsScreen()),
            ),
      },
      {
        'icon': Icons.card_giftcard_rounded,
        'title': '내 기프티콘',
        'color': AppTheme.accentGreen,
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyGifticonsScreen()),
            ),
      },
    ];

    final listItems = [
      {
        'icon': Icons.history_rounded,
        'title': '크레딧 내역',
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreditHistoryScreen()),
            ),
      },
      {
        'icon': Icons.bar_chart_rounded,
        'title': '집중 통계',
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FocusStatsScreen()),
            ),
      },
      {
        'icon': Icons.privacy_tip_outlined,
        'title': '개인정보 처리방침',
        'onTap': () =>
            _showTermsBottomSheet(context, '개인정보 처리방침', privacyPolicyText),
      },
      {
        'icon': Icons.description_outlined,
        'title': '이용약관',
        'onTap': () =>
            _showTermsBottomSheet(context, '서비스 이용약관', serviceTermsText),
      },
    ];

    return Column(
      children: [
        // 자주 쓰는 기능 - 큰 그리드 카드
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: quickItems.map((item) {
            final color = item['color'] as Color;
            return GestureDetector(
              onTap: item['onTap'] as VoidCallback,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.of(context).card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.07),
                      blurRadius: 12,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(item['icon'] as IconData,
                          color: color, size: 24),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item['title'] as String,
                          style: TextStyle(
                            color: AppTheme.of(context).textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded,
                            color: color.withValues(alpha: 0.6), size: 14),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        // 기타 설정 - 리스트
        Container(
          decoration: BoxDecoration(
            color: AppTheme.of(context).card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.of(context).borderSubtle),
          ),
          child: Column(
            children: List.generate(listItems.length, (index) {
              final item = listItems[index];
              final isLast = index == listItems.length - 1;
              return Column(
                children: [
                  ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.of(context).surface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(item['icon'] as IconData,
                          color: AppTheme.of(context).textSecondary, size: 18),
                    ),
                    title: Text(
                      item['title'] as String,
                      style: TextStyle(
                        color: AppTheme.of(context).textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: Icon(Icons.chevron_right_rounded,
                        color: AppTheme.of(context).textMuted, size: 20),
                    onTap: item['onTap'] as VoidCallback,
                  ),
                  if (!isLast)
                    Divider(
                      height: 1,
                      color: AppTheme.of(context).borderSubtle,
                      indent: 56,
                    ),
                ],
              );
            }),
          ),
        ),
        const SizedBox(height: 12),

        // 다크 모드 토글
        Consumer<ThemeProvider>(
          builder: (context, themeProvider, _) => Container(
            decoration: BoxDecoration(
              color: AppTheme.of(context).card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.of(context).borderSubtle),
            ),
            child: SwitchListTile(
              secondary: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.of(context).surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  themeProvider.isDark
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  color: AppTheme.of(context).textSecondary,
                  size: 18,
                ),
              ),
              title: Text(
                '다크 모드',
                style: TextStyle(
                  color: AppTheme.of(context).textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              value: themeProvider.isDark,
              onChanged: (_) => themeProvider.toggle(),
              activeThumbColor: AppTheme.primaryColor,
              activeTrackColor: AppTheme.primaryColor.withValues(alpha: 0.5),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 로그아웃
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () async {
              await context.read<AuthProvider>().signOut();
              if (context.mounted) {
                Navigator.of(context)
                    .pushNamedAndRemoveUntil(AppRoutes.login, (r) => false);
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.accentRed,
              side: BorderSide(
                  color: AppTheme.accentRed.withValues(alpha: 0.3), width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text(
              '로그아웃',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // 계정 탈퇴
        TextButton(
          onPressed: () => _showDeleteAccountDialog(context),
          child: Text(
            '계정 탈퇴',
            style: TextStyle(color: AppTheme.of(context).textMuted, fontSize: 13),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  void _showTermsBottomSheet(
      BuildContext context, String title, String content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, controller) => Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.of(context).textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                title,
                style: TextStyle(
                  color: AppTheme.of(context).textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                controller: controller,
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  content,
                  style: TextStyle(
                    color: AppTheme.of(context).textSecondary,
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                decoration: AppTheme.glowButton,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: const Text('확인'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.of(context).card,
        title: Text(
          '계정 탈퇴',
          style: TextStyle(color: AppTheme.of(context).textPrimary),
        ),
        content: Text(
          '탈퇴하면 모든 크레딧과 집중 기록이 삭제되며\n복구할 수 없습니다.\n\n정말 탈퇴하시겠습니까?',
          style: TextStyle(color: AppTheme.of(context).textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              '취소',
              style: TextStyle(color: AppTheme.of(context).textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<AuthProvider>().deleteAccount();
              if (context.mounted) {
                Navigator.of(context)
                    .pushNamedAndRemoveUntil(AppRoutes.login, (r) => false);
              }
            },
            child: const Text(
              '탈퇴하기',
              style: TextStyle(color: AppTheme.accentRed),
            ),
          ),
        ],
      ),
    );
  }
}
