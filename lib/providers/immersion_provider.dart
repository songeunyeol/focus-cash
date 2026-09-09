import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 몰입 모드 on/off. 기기 로컬 설정.
///
/// 집중 중 15초 무조작이면 검정 화면 + 창 밝기 저하로 들어간다.
/// Firestore 에 둘 값이 아니라 기기 취향이라 SharedPreferences 가 맞다.
class ImmersionProvider extends ChangeNotifier {
  static const String prefsKey = 'immersion_enabled';

  bool _enabled = true;
  bool _loaded = false;

  bool get enabled => _enabled;
  bool get isLoaded => _loaded;

  ImmersionProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(prefsKey) ?? true;
    } catch (e) {
      debugPrint('몰입 설정 불러오기 실패 (기본 on): $e');
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;
    _enabled = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefsKey, value);
    } catch (e) {
      debugPrint('몰입 설정 저장 실패: $e');
    }
  }
}
