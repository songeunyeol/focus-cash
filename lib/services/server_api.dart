import 'package:cloud_functions/cloud_functions.dart';

/// Cloud Functions 호출 래퍼. 함수 이름·리전·입출력 형태를 한 곳에 둔다.
///
/// 각 메서드는 functions/src/*.ts 의 같은 이름 함수와 1:1 이다.
/// 실패는 [FirebaseFunctionsException] 으로 올라오며 `code` 가 서버의 HttpsError 코드다
/// (already-exists, failed-precondition, resource-exhausted, permission-denied ...).
class ServerApi {
  ServerApi({FirebaseFunctions? functions})
      : _fn = functions ??
            FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  final FirebaseFunctions _fn;

  Future<Map<String, dynamic>> _call(
      String name, Map<String, dynamic> data) async {
    final result = await _fn
        .httpsCallable(name,
            options: HttpsCallableOptions(timeout: const Duration(seconds: 15)))
        .call<Map<String, dynamic>>(data);
    return Map<String, dynamic>.from(result.data);
  }

  /// 세션 정산. 서버가 경과 시간을 검증하고 크레딧·XP·스트릭·배지를 한 번에 반영한다.
  Future<SettleResult> settleSession(String sessionId) async {
    final r = await _call('settleSession', {'sessionId': sessionId});
    return SettleResult(
      credits: r['credits'] as int? ?? 0,
      firstFocusBonus: r['firstFocusBonus'] as int? ?? 0,
      xpGained: r['xpGained'] as int? ?? 0,
      badgeXpGained: r['badgeXpGained'] as int? ?? 0,
      oldLevel: r['oldLevel'] as int? ?? 0,
      newLevel: r['newLevel'] as int? ?? 0,
      newBadges: (r['newBadges'] as List<dynamic>?)?.cast<String>() ?? const [],
      currentStreak: r['currentStreak'] as int? ?? 0,
    );
  }

  /// 광고 보너스. kind: 'start' | 'end'. 실제 지급량을 돌려준다.
  Future<int> grantAdBonus(String sessionId, String kind) async {
    final r = await _call('grantAdBonus', {'sessionId': sessionId, 'kind': kind});
    return r['granted'] as int? ?? 0;
  }

  Future<Map<String, dynamic>> redeemGifticon(String storeItemId) =>
      _call('redeemGifticon', {'storeItemId': storeItemId});

  Future<Map<String, dynamic>> spinRoulette() => _call('spinRoulette', {});

  Future<Map<String, dynamic>> enterRaffle(String roomId, int tickets) =>
      _call('enterRaffle', {'roomId': roomId, 'tickets': tickets});

  /// 카카오 액세스 토큰 → Firebase custom token
  Future<({String token, bool isNewUser})> kakaoSignIn(String accessToken) async {
    final r = await _call('kakaoSignIn', {'accessToken': accessToken});
    return (
      token: r['token'] as String,
      isNewUser: r['isNewUser'] as bool? ?? false,
    );
  }
}

class SettleResult {
  const SettleResult({
    required this.credits,
    required this.firstFocusBonus,
    required this.xpGained,
    required this.badgeXpGained,
    required this.oldLevel,
    required this.newLevel,
    required this.newBadges,
    required this.currentStreak,
  });

  final int credits;
  final int firstFocusBonus;
  final int xpGained;
  final int badgeXpGained;
  final int oldLevel;
  final int newLevel;
  final List<String> newBadges;
  final int currentStreak;
}
