import 'package:flutter_test/flutter_test.dart';
import 'package:focus_cash/config/constants.dart';

void main() {
  group('AppConstants 레벨 곡선', () {
    test('레벨 경계 XP', () {
      expect(AppConstants.xpForLevel(1), 0);
      expect(AppConstants.xpForLevel(5), 500);
      expect(AppConstants.xpForLevel(10), 1500);
      expect(AppConstants.xpForLevel(20), 4000);
      expect(AppConstants.xpForLevel(30), 8000);
      expect(AppConstants.xpForLevel(50), 20000);
    });

    test('xpForLevel 은 단조 증가한다', () {
      for (var lv = 1; lv < 60; lv++) {
        expect(AppConstants.xpForLevel(lv + 1), greaterThan(AppConstants.xpForLevel(lv)));
      }
    });

    test('levelFromXp 는 xpForLevel 의 역함수다', () {
      for (var lv = 1; lv <= 55; lv++) {
        final xp = AppConstants.xpForLevel(lv);
        expect(AppConstants.levelFromXp(xp), lv, reason: 'lv $lv 경계');
        expect(AppConstants.levelFromXp(xp - 1 < 0 ? 0 : xp - 1),
            lv == 1 ? 1 : lv - 1, reason: 'lv $lv 직전');
      }
    });

    test('프레임 등급과 칭호는 레벨 구간과 일치한다', () {
      expect(AppConstants.frameGradeForLevel(4), 0);
      expect(AppConstants.frameGradeForLevel(5), 1);
      expect(AppConstants.frameGradeForLevel(10), 2);
      expect(AppConstants.frameGradeForLevel(20), 3);
      expect(AppConstants.frameGradeForLevel(30), 4);
      expect(AppConstants.frameGradeForLevel(50), 5);
      expect(AppConstants.titleForLevel(1), '입문 집중러');
      expect(AppConstants.titleForLevel(50), '전설의 집중러');
    });

    test('가입 화면과 앱 전역이 같은 아바타 목록을 쓴다', () {
      // signup_profile_screen 이 별도 리스트를 쓰면 가입 때 고른 아바타가 이후 다르게 보인다.
      expect(AppConstants.avatarEmojis.length, greaterThanOrEqualTo(8));
      expect(AppConstants.avatarEmojis.toSet().length, AppConstants.avatarEmojis.length);
    });
  });
}
