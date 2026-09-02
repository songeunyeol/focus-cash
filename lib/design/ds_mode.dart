import 'package:flutter/widgets.dart';

/// Focus Cash 는 성격이 반대인 두 순간이 공존한다.
/// 하나의 톤으로 밀면 둘 중 하나가 죽으므로 모드를 나누고 컴포넌트가 자동 분기한다.
enum DsMode {
  /// 계기 — 집중·설정·통계·캘린더·랭킹·친구·상점 교환탭.
  /// 무채색, 헤어라인, 각진 radius, 절제된 모션. 액센트는 화면당 한 곳.
  instrument,

  /// 보상 — 완료·크레딧 획득·룰렛·응모 당첨·레벨업·배지.
  /// pill, 굵기 700/400 이진, 대문자 마이크로 라벨, 액센트 면적 허용, 스프링 모션.
  reward,

  /// 몰입 — 집중 중 무조작 상태. 순수 검정, 타이머만 잔존, 저휘도.
  immersion,
}

extension DsModeX on DsMode {
  bool get isReward => this == DsMode.reward;
  bool get isImmersion => this == DsMode.immersion;
  bool get isInstrument => this == DsMode.instrument;
}

/// 하위 트리에 모드를 전파한다.
/// 화면마다 컴포넌트 variant 를 손으로 지정하지 않아도 되게 하는 장치.
class DsModeScope extends InheritedWidget {
  const DsModeScope({
    super.key,
    required this.mode,
    required super.child,
  });

  final DsMode mode;

  /// 감싸지 않은 곳은 계기 모드가 기본이다.
  static DsMode of(BuildContext context) {
    final DsModeScope? scope =
        context.dependOnInheritedWidgetOfExactType<DsModeScope>();
    return scope?.mode ?? DsMode.instrument;
  }

  @override
  bool updateShouldNotify(DsModeScope oldWidget) => mode != oldWidget.mode;
}
