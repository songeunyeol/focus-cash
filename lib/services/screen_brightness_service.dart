import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 현재 창의 화면 밝기만 바꾼다. WRITE_SETTINGS 권한은 필요 없다.
///
/// Android [WindowManager.LayoutParams.screenBrightness] 에 대응한다.
/// 값 범위는 0~1, 음수는 시스템 기본값 복원.
class ScreenBrightnessService {
  ScreenBrightnessService._();

  static const MethodChannel _channel = MethodChannel('focuscash/screen');

  /// 창에 덮어쓴 밝기. 시스템 기본이면 null.
  static Future<double?> getWindowBrightness() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final double? value =
          await _channel.invokeMethod<double>('getBrightness');
      if (value == null || value < 0) return null;
      return value;
    } on PlatformException catch (e) {
      debugPrint('ScreenBrightnessService.get 실패: ${e.message}');
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// [value] 가 null 이면 시스템 밝기로 되돌린다.
  static Future<void> setWindowBrightness(double? value) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>(
        'setBrightness',
        <String, double>{'value': value ?? -1},
      );
    } on PlatformException catch (e) {
      debugPrint('ScreenBrightnessService.set 실패: ${e.message}');
    } on MissingPluginException {
      // 채널 미연결 — 밝기만 안 바뀌고 몰입 화면은 그대로 동작한다.
    }
  }
}
