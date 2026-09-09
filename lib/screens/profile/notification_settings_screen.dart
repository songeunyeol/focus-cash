import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../design/ds.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';

/// 알림 설정.
///
/// 이용약관·마케팅 동의 문구가 "[프로필 > 설정 > 알림 설정]에서 수신을 거부할 수 있다"고
/// 안내하는데 그 화면이 없었다. 마케팅 동의 철회 경로는 정보통신망법상 필수다.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  static const String kStreakReminderKey = 'streak_reminder_enabled';

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _streakReminder = true;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _streakReminder =
          prefs.getBool(NotificationSettingsScreen.kStreakReminderKey) ?? true;
    } catch (_) {}
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _setStreakReminder(bool on) async {
    final streak = context.read<AuthProvider>().user?.currentStreak ?? 0;
    setState(() => _streakReminder = on);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(NotificationSettingsScreen.kStreakReminderKey, on);
    } catch (_) {}
    if (on) {
      await NotificationService.instance
          .scheduleStreakReminder(currentStreak: streak);
    } else {
      await NotificationService.instance.cancelStreakReminder();
    }
  }

  Future<void> _setMarketing(bool on) async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;
    auth.updateUser(user.copyWith(marketingAgreed: on));
    try {
      await AuthService().updateMarketingAgreed(uid: user.uid, agreed: on);
    } catch (e) {
      // 실패하면 원복
      auth.updateUser(user.copyWith(marketingAgreed: !on));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장하지 못했어요. 잠시 후 다시 시도해주세요.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(title: const Text('알림 설정')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(Sp.x4),
              children: <Widget>[
                DecoratedBox(
                  decoration: DsSurface.e1(c),
                  child: Column(
                    children: <Widget>[
                      SwitchListTile(
                        title: Text('스트릭 리마인더',
                            style: DsType.bodyStrong.on(c.textPrimary)),
                        subtitle: Text('오늘 집중을 안 했으면 밤 9시에 알려줘요',
                            style: DsType.caption.on(c.textSecondary)),
                        value: _streakReminder,
                        onChanged: _setStreakReminder,
                        activeThumbColor: c.flame,
                      ),
                      Divider(color: c.borderSubtle, height: Stroke.hairline),
                      SwitchListTile(
                        title: Text('마케팅 정보 수신',
                            style: DsType.bodyStrong.on(c.textPrimary)),
                        subtitle: Text('이벤트·신규 상품·프로모션 안내 (선택)',
                            style: DsType.caption.on(c.textSecondary)),
                        value: user?.marketingAgreed ?? false,
                        onChanged: user == null ? null : _setMarketing,
                        activeThumbColor: c.flame,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Sp.x3),
                Text(
                  '집중 완료 알림은 화면이 꺼진 채로 세션이 끝났을 때만 표시돼요. '
                  '기기 설정에서 앱 알림을 끄면 모든 알림이 중단됩니다.',
                  style: DsType.caption.on(c.textTertiary),
                ),
              ],
            ),
    );
  }
}
