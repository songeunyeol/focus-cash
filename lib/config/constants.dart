class AppConstants {
  AppConstants._();

  // 앱 전역 아바타 이모지 (4곳에서 중복 정의되던 것 통합)
  static const List<String> avatarEmojis = [
    '🦁', '🐯', '🦊', '🐻', '🐼', '🦄', '🐙', '🦋', '🐬', '🦅',
  ];

  // Credit Economy
  static const int creditsPerTenMinutes = 10;
  static const int startAdBonus = 15;
  static const double endAdMultiplierRate = 0.2; // 종료 광고 시청 시 기본 크레딧 20% 보너스
  static const int rouletteCost = 50;
  static const int rouletteDailyLimit = 3;
  static const int coffeeCouponCost = 6500;
  static const int signupBonus = 200;
  static const int referralBonus = 200;

  // Timer
  static const int minFocusMinutes = 10;
  static const int maxFocusMinutes = 120;

  // Hardcore Mode
  static const double hardcorePenaltyRate = 0.10;
  static const double hardcoreBonusRate = 1.2;

  // Roulette prizes
  static const List<Map<String, dynamic>> roulettePrizes = [
    {'name': '10 크레딧', 'credits': 10, 'probability': 40},
    {'name': '50 크레딧', 'credits': 50, 'probability': 25},
    {'name': '100 크레딧', 'credits': 100, 'probability': 15},
    {'name': '200 크레딧', 'credits': 200, 'probability': 10},
    {'name': '500 크레딧', 'credits': 500, 'probability': 7},
    {'name': '1000 크레딧', 'credits': 1000, 'probability': 3},
  ];

  // ── XP 경제 ────────────────────────────────
  static const int checkInXp = 10;             // 출석 체크
  static const double focusXpPerMinute = 1.0;  // 집중 완료 1분당 1XP
  static const double hardcoreXpMultiplier = 1.2; // 하드코어 완료 배율
  static const int badgeXp = 50;               // 배지 획득 시 보너스

  // ── 레벨 시스템 ────────────────────────────
  // 누적 XP → 레벨 계산
  // 레벨 1~4: 125 XP/레벨
  // 레벨 5~9: 200 XP/레벨  (lv5 = 500 XP)
  // 레벨 10~19: 250 XP/레벨 (lv10 = 1500 XP)
  // 레벨 20~29: 400 XP/레벨 (lv20 = 4000 XP)
  // 레벨 30~49: 600 XP/레벨 (lv30 = 8000 XP)
  // 레벨 50+: 1000 XP/레벨  (lv50 = 20000 XP)
  static int xpForLevel(int level) {
    if (level <= 1) return 0;
    if (level <= 5) return (level - 1) * 125;
    if (level <= 10) return 500 + (level - 5) * 200;
    if (level <= 20) return 1500 + (level - 10) * 250;
    if (level <= 30) return 4000 + (level - 20) * 400;
    if (level <= 50) return 8000 + (level - 30) * 600;
    return 20000 + (level - 50) * 1000;
  }

  static int levelFromXp(int xp) {
    int lv = 1;
    while (xpForLevel(lv + 1) <= xp) {
      lv++;
    }
    return lv;
  }

  // 레벨 칭호 (해당 레벨 이상이면 적용)
  static String titleForLevel(int level) {
    if (level >= 50) return '전설의 집중러';
    if (level >= 30) return '집중 마스터';
    if (level >= 20) return '집중 달인';
    if (level >= 10) return '집중 탐구자';
    if (level >= 5) return '성장하는 집중러';
    return '입문 집중러';
  }

  // 레벨 프레임 등급 (0=없음, 1=청동, 2=실버, 3=골드, 4=인디고, 5=그라디언트)
  static int frameGradeForLevel(int level) {
    if (level >= 50) return 5;
    if (level >= 30) return 4;
    if (level >= 20) return 3;
    if (level >= 10) return 2;
    if (level >= 5) return 1;
    return 0;
  }

  // ── 배지 정의 ──────────────────────────────
  static const List<Map<String, dynamic>> badgeDefinitions = [
    {
      'id': 'first_focus',
      'name': '첫 걸음',
      'desc': '처음으로 집중 세션을 완료했어요',
      'icon': '🎯',
    },
    {
      'id': 'focus_10h',
      'name': '10시간 돌파',
      'desc': '누적 집중 시간 10시간 달성',
      'icon': '⏰',
    },
    {
      'id': 'focus_100h',
      'name': '100시간 달인',
      'desc': '누적 집중 시간 100시간 달성',
      'icon': '🏅',
    },
    {
      'id': 'streak_7',
      'name': '일주일의 의지',
      'desc': '7일 연속 집중 완료',
      'icon': '📅',
    },
    {
      'id': 'streak_30',
      'name': '한 달의 기적',
      'desc': '30일 연속 집중 완료',
      'icon': '🌙',
    },
    {
      'id': 'hardcore_10',
      'name': '강철 의지',
      'desc': '하드코어 모드 10회 완료',
      'icon': '💎',
    },
    {
      'id': 'early_bird',
      'name': '새벽 전사',
      'desc': '오전 6시 이전에 집중 완료',
      'icon': '🌅',
    },
    {
      'id': 'night_owl',
      'name': '야행성 집중러',
      'desc': '자정 이후에 집중 완료',
      'icon': '🌙',
    },
    {
      'id': 'level_5',
      'name': '성장의 증거',
      'desc': '레벨 5 달성',
      'icon': '⭐',
    },
    {
      'id': 'level_10',
      'name': '집중의 길',
      'desc': '레벨 10 달성',
      'icon': '🌟',
    },
    {
      'id': 'invite_3',
      'name': '소문내기',
      'desc': '친구 3명 초대 성공',
      'icon': '👥',
    },
    {
      'id': 'full_day',
      'name': '풀집중',
      'desc': '하루에 120분 집중 완료',
      'icon': '🔥',
    },
  ];

  static Map<String, dynamic>? badgeById(String id) {
    try {
      return badgeDefinitions.firstWhere((b) => b['id'] == id);
    } catch (_) {
      return null;
    }
  }
}
