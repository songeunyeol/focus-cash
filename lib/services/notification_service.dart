import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // ── 초기화 ────────────────────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    // 기기 시간대 자동 사용 (해외 사용자 대응)
    final localTz = DateTime.now().timeZoneName;
    try {
      tz.setLocalLocation(tz.getLocation(localTz));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Seoul')); // 폴백
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(
          android: androidSettings, iOS: iosSettings),
    );

    // Android 13+ 알림 권한 요청
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  // ── 채널 ─────────────────────────────────────────────────────
  static const _streakDetails = AndroidNotificationDetails(
    'streak_reminder',
    '스트릭 알림',
    channelDescription: '연속 집중 스트릭 유지 알림',
    importance: Importance.high,
    priority: Priority.high,
    icon: '@mipmap/ic_launcher',
  );

  static const _focusDoneDetails = AndroidNotificationDetails(
    'focus_done',
    '집중 완료 알림',
    channelDescription: '집중 완료 축하 알림',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    icon: '@mipmap/ic_launcher',
  );

  static const _friendDetails = AndroidNotificationDetails(
    'friend_request',
    '친구 요청 알림',
    channelDescription: '친구 요청 수신 알림',
    importance: Importance.high,
    priority: Priority.high,
    icon: '@mipmap/ic_launcher',
  );

  // ── 스트릭 유지 리마인더 (매일 오후 9시) ─────────────────────
  Future<void> scheduleStreakReminder({required int currentStreak}) async {
    await init();

    // 기존 스트릭 알림 취소 후 재등록
    await _plugin.cancel(1);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 21);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    final body = currentStreak > 0
        ? '오늘 집중 안 하면 $currentStreak일 스트릭이 끊겨요! 🔥'
        : '오늘도 집중하고 스트릭을 시작해볼까요? 🎯';

    await _plugin.zonedSchedule(
      1,
      '포커스캐시',
      body,
      scheduled,
      const NotificationDetails(android: _streakDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // 매일 오후 9시 반복
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ── 스트릭 알림 취소 ──────────────────────────────────────────
  Future<void> cancelStreakReminder() async {
    await _plugin.cancel(1);
  }

  /// 오늘 집중 완료 시 호출 — 오늘 밤 알림을 취소하고 내일 밤으로 재스케줄
  /// (Duolingo 스타일: 오늘 이미 집중했으니 오늘 알림 불필요)
  Future<void> rescheduleStreakReminderToTomorrow({
    required int currentStreak,
  }) async {
    await init();
    await _plugin.cancel(1);

    final now = tz.TZDateTime.now(tz.local);
    // 항상 내일 오후 9시로 예약 (월말 경계 안전 처리)
    final tomorrow = now.add(const Duration(days: 1));
    final scheduled = tz.TZDateTime(
      tz.local,
      tomorrow.year,
      tomorrow.month,
      tomorrow.day,
      21,
    );

    final body = currentStreak > 0
        ? '오늘도 집중하고 $currentStreak일 스트릭을 이어가세요! 🔥'
        : '오늘도 집중하고 스트릭을 시작해볼까요? 🎯';

    await _plugin.zonedSchedule(
      1,
      '포커스캐시',
      body,
      scheduled,
      const NotificationDetails(android: _streakDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ── 집중 완료 즉시 알림 (백그라운드에서 완료 시) ──────────────
  Future<void> showFocusCompleted({
    required int minutes,
    required int credits,
  }) async {
    await init();
    await _plugin.show(
      2,
      '집중 완료! 🎉',
      '$minutes분 집중으로 $credits크레딧을 획득했어요!',
      const NotificationDetails(android: _focusDoneDetails),
    );
  }

  // ── 친구 요청 알림 ────────────────────────────────────────────
  Future<void> showFriendRequest({required String fromName}) async {
    await init();
    await _plugin.show(
      3,
      '친구 요청',
      '$fromName님이 친구 요청을 보냈어요!',
      const NotificationDetails(android: _friendDetails),
    );
  }
}
