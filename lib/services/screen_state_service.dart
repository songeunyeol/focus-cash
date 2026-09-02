import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 기기 화면의 켜짐/꺼짐 상태를 조회한다.
///
/// Flutter 는 화면 꺼짐과 앱 이탈을 모두 [AppLifecycleState.paused] 로 전달하므로
/// 둘을 구분하려면 플랫폼 신호가 필요하다. 집중 세션이 화면 꺼짐만으로 포기 처리되는
/// 것을 막기 위해 사용한다.
class ScreenStateService {
  ScreenStateService._();

  static const MethodChannel _channel = MethodChannel('focuscash/screen');

  /// 화면이 꺼져 있으면 true.
  ///
  /// Android 외 플랫폼이나 채널 미연결 시에는 false 를 돌려준다.
  /// (false = "앱 이탈로 간주" 이므로 기존 동작과 같아 안전한 기본값이다)
  static Future<bool> isScreenOff() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await _channel.invokeMethod<bool>('isScreenOff') ?? false;
    } on PlatformException catch (e) {
      debugPrint('ScreenStateService.isScreenOff 실패: ${e.message}');
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
