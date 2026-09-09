import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// 퍼널을 보기 위한 최소 이벤트 집합.
///
/// firebase_analytics 는 처음부터 의존성에 있었지만 이벤트를 하나도 찍지 않았다.
/// 시작→완료→포기→소비 네 지점만 있어도 "어디서 이탈하나"가 보인다.
/// 실패는 전부 무시한다 — 분석이 앱을 죽이면 안 된다.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  FirebaseAnalytics get _fa => FirebaseAnalytics.instance;

  Future<void> _log(String name, [Map<String, Object>? params]) async {
    try {
      await _fa.logEvent(name: name, parameters: params);
    } catch (e) {
      debugPrint('[Analytics] $name 실패: $e');
    }
  }

  Future<void> sessionStart({
    required int targetMinutes,
    required String mode,
    required bool withAd,
  }) =>
      _log('focus_start', {
        'target_minutes': targetMinutes,
        'mode': mode,
        'with_ad': withAd ? 1 : 0,
      });

  Future<void> sessionComplete({
    required int actualMinutes,
    required int credits,
    required String mode,
  }) =>
      _log('focus_complete', {
        'actual_minutes': actualMinutes,
        'credits': credits,
        'mode': mode,
      });

  Future<void> sessionAbandon({
    required int elapsedMinutes,
    required String mode,
    required String reason,
  }) =>
      _log('focus_abandon', {
        'elapsed_minutes': elapsedMinutes,
        'mode': mode,
        'reason': reason,
      });

  Future<void> sessionRecovered(String action) =>
      _log('focus_recovered', {'action': action});

  Future<void> exchange({required String itemId, required int cost}) =>
      _log('store_exchange', {'item_id': itemId, 'cost': cost});

  Future<void> rouletteSpin({required int cost, required String prize}) =>
      _log('roulette_spin', {'cost': cost, 'prize': prize});

  /// 몰입 모드 진입/이탈. 얼마나 자주 켜지는지가 광고 노출 감소량이기도 하다.
  Future<void> immersionToggled({required bool entered}) =>
      _log('immersion_toggle', {'entered': entered ? 1 : 0});

  Future<void> raffleEnter({required String roomId, required int tickets}) =>
      _log('raffle_enter', {'room_id': roomId, 'tickets': tickets});
}
