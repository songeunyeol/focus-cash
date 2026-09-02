import 'package:flutter/widgets.dart';

/// 간격 스케일. 4px 배수 7단계로 고정한다.
/// 리뉴얼 이전에는 EdgeInsets 조합이 30종 이상 흩어져 있었다.
abstract final class Sp {
  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 12;
  static const double x4 = 16;
  static const double x6 = 24;
  static const double x8 = 32;
  static const double x12 = 48;

  /// 화면 좌우 기본 여백
  static const EdgeInsets screenH = EdgeInsets.symmetric(horizontal: x4);

  /// 카드 내부 기본 여백
  static const EdgeInsets card = EdgeInsets.all(x4);
}

/// 모서리 반경 4단계. 이전에는 10종이 혼재했다.
abstract final class R {
  static const double sm = 6; // 버튼·배지·인풋
  static const double md = 12; // 카드
  static const double lg = 20; // 바텀시트·큰 패널
  static const double pill = 999; // 보상 모드 필 버튼·칩

  static const BorderRadius rSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius rMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius rLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius rPill = BorderRadius.all(Radius.circular(pill));

  /// 바텀시트 상단만 둥글게
  static const BorderRadius rSheet = BorderRadius.vertical(top: Radius.circular(lg));
}

/// 테두리 두께
abstract final class Stroke {
  static const double hairline = 1;
  static const double thick = 2;
}

/// 모션 규칙. 인터랙션은 색 변경이 아니라 불투명도 전환으로 표현한다.
abstract final class Motion {
  static const Duration micro = Duration(milliseconds: 120);
  static const Duration standard = Duration(milliseconds: 200);
  static const Duration page = Duration(milliseconds: 320);

  static const Curve curve = Curves.easeOutCubic;

  /// 눌림 상태 불투명도
  static const double pressedOpacity = 0.6;

  /// 비활성 불투명도
  static const double disabledOpacity = 0.38;
}
