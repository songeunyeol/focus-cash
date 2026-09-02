import 'package:flutter/material.dart';

/// 타입 스케일 10역할.
/// 리뉴얼 이전에는 fontSize 가 21종 흩어져 있었고 인라인 TextStyle 이 296회 있었다.
///
/// 규칙:
///  - 다크 배경에서 글자가 얇아 보이는 것을 막기 위해 본문 기본 굵기는 500이다.
///  - letterSpacing 이 양수인 것은 의도적이다. 어두운 배경에서 자간이 뭉치는 것을 푼다.
///  - 한글은 라틴보다 행간이 넉넉해야 한다. body 는 1.6.
///  - 색은 여기서 정하지 않는다. 호출부가 [DsTextStyleX.on] 으로 주입한다.
abstract final class DsType {
  /// 숫자 고정폭. 값이 바뀌어도 폭이 흔들리지 않게 한다.
  static const List<FontFeature> _tnum = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  /// 집중 타이머 전용
  static const TextStyle timerDisplay = TextStyle(
    fontSize: 56,
    fontWeight: FontWeight.w600,
    height: 1.00,
    letterSpacing: -1.0,
    fontFeatures: _tnum,
  );

  static const TextStyle display = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.4,
  );

  static const TextStyle title = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.30,
    letterSpacing: -0.3,
  );

  static const TextStyle heading = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.35,
    letterSpacing: -0.2,
  );

  static const TextStyle subhead = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.40,
  );

  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.60,
    letterSpacing: 0.1,
  );

  static const TextStyle bodyStrong = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.60,
    letterSpacing: 0.1,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.50,
    letterSpacing: 0.2,
  );

  static const TextStyle label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.40,
    letterSpacing: 0.2,
  );

  /// 보상 모드 마이크로 라벨. 대문자 변환은 컴포넌트가 담당한다.
  static const TextStyle micro = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 1.30,
    letterSpacing: 1.4,
  );
}

extension DsTextStyleX on TextStyle {
  /// 색 주입. `DsType.body.on(c.textSecondary)` 형태로 쓴다.
  TextStyle on(Color color) => copyWith(color: color);

  /// 숫자 고정폭 적용. 크레딧·랭킹·시간 표시에 쓴다.
  TextStyle get tnum => copyWith(
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      );

  /// 몰입 모드 저휘도
  TextStyle dim(Color dimColor) => copyWith(color: dimColor);
}
