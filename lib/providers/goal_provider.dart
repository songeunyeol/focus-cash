import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/goal_rules.dart';

/// 하루 집중 목표(분). 홈 다이얼의 기준값이다.
///
/// 기기 로컬(SharedPreferences)에 저장한다. Firestore `users` 문서에 두면 규칙 v2 의
/// 허용 필드 목록을 늘려야 하고, 목표는 기기마다 달라도 무방한 값이라 로컬이 맞다.
class GoalProvider extends ChangeNotifier {
  static const String _key = 'daily_goal_minutes';

  int _minutes = GoalRules.defaultMinutes;
  bool _loaded = false;

  int get dailyGoalMinutes => _minutes;
  bool get isLoaded => _loaded;

  GoalProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt(_key);
      if (saved != null) _minutes = GoalRules.normalize(saved);
    } catch (e) {
      debugPrint('목표 불러오기 실패 (기본값 사용): $e');
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setGoal(int minutes) async {
    final next = GoalRules.normalize(minutes);
    if (next == _minutes) return;
    _minutes = next;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key, next);
    } catch (e) {
      debugPrint('목표 저장 실패: $e');
    }
  }

  Future<void> increase() => setGoal(_minutes + GoalRules.stepMinutes);
  Future<void> decrease() => setGoal(_minutes - GoalRules.stepMinutes);
}
