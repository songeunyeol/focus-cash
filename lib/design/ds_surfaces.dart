import 'package:flutter/material.dart';

import 'ds_colors.dart';
import 'ds_dimens.dart';

/// 표면 깊이 4단계.
///
/// 다크에서는 검정 위의 검정 그림자가 보이지 않으므로 표면 명도와 헤어라인으로,
/// 라이트에서는 실제 그림자로 깊이를 만든다. 분기는 [DsColors.useElevationShadow] 가 쥔다.
/// 호출부는 어느 테마인지 몰라도 된다.
enum DsElevation {
  /// 페이지 배경. 보더 없음
  e0,

  /// 카드
  e1,

  /// 바텀시트·다이얼로그. 상단 1px 하이라이트가 붙는다
  e2,

  /// 보상 모먼트·모달. 무거운 그림자
  e3,
}

abstract final class DsSurface {
  /// 표면 데코레이션을 만든다.
  ///
  /// [tone] 을 주면 배경 대신 그 색을 쓴다 (틴트 카드 등).
  static BoxDecoration of(
    DsColors c,
    DsElevation elevation, {
    BorderRadius? radius = R.rMd,
    Color? tone,
    Color? borderColor,
    bool border = true,
  }) {
    final Color bgColor = tone ?? _background(c, elevation);
    final Color line = borderColor ?? _border(c, elevation);

    return BoxDecoration(
      color: bgColor,
      borderRadius: radius,
      border: border
          ? Border.all(color: line, width: Stroke.hairline)
          : null,
      boxShadow: _shadow(c, elevation),
    );
  }

  static BoxDecoration e0(DsColors c, {BorderRadius? radius}) =>
      of(c, DsElevation.e0, radius: radius, border: false);

  static BoxDecoration e1(DsColors c,
          {BorderRadius? radius = R.rMd, Color? tone}) =>
      of(c, DsElevation.e1, radius: radius, tone: tone);

  static BoxDecoration e2(DsColors c, {BorderRadius? radius = R.rLg}) =>
      of(c, DsElevation.e2, radius: radius);

  static BoxDecoration e3(DsColors c, {BorderRadius? radius = R.rLg}) =>
      of(c, DsElevation.e3, radius: radius);

  /// 액센트 틴트 면. 배지·강조 카드에 쓴다.
  static BoxDecoration tint(
    DsColors c,
    Color tone, {
    BorderRadius? radius = R.rSm,
    bool border = false,
  }) {
    return BoxDecoration(
      color: tone,
      borderRadius: radius,
      border: border
          ? Border.all(color: c.borderSubtle, width: Stroke.hairline)
          : null,
    );
  }

  /// 헤어라인 구분선 색
  static Color divider(DsColors c) => c.borderSubtle;

  static Color _background(DsColors c, DsElevation e) => switch (e) {
        DsElevation.e0 => c.bg,
        DsElevation.e1 => c.surface,
        DsElevation.e2 => c.surfaceRaised,
        DsElevation.e3 => c.surfaceRaised,
      };

  static Color _border(DsColors c, DsElevation e) => switch (e) {
        DsElevation.e0 => c.borderSubtle,
        DsElevation.e1 => c.borderSubtle,
        DsElevation.e2 => c.borderDefault,
        DsElevation.e3 => c.borderDefault,
      };

  static List<BoxShadow>? _shadow(DsColors c, DsElevation e) => switch (e) {
        DsElevation.e0 => null,
        DsElevation.e1 => c.shadowE1.isEmpty ? null : c.shadowE1,
        DsElevation.e2 => c.shadowE2.isEmpty ? null : c.shadowE2,
        DsElevation.e3 => c.shadowE3.isEmpty ? null : c.shadowE3,
      };
}

/// e2 이상에서 상단 1px 하이라이트를 얹어 물리적 질감을 만든다.
/// (BoxDecoration 단독으로는 inset 을 표현할 수 없어 별도 위젯으로 둔다)
class DsRaisedSurface extends StatelessWidget {
  const DsRaisedSurface({
    super.key,
    required this.colors,
    required this.child,
    this.elevation = DsElevation.e2,
    this.radius = R.rLg,
    this.padding,
  });

  final DsColors colors;
  final Widget child;
  final DsElevation elevation;
  final BorderRadius radius;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: DsSurface.of(colors, elevation, radius: radius),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: <Widget>[
            Padding(
              padding: padding ?? EdgeInsets.zero,
              child: child,
            ),
            if (colors.insetHighlight.a > 0)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Container(
                    height: Stroke.hairline,
                    color: colors.insetHighlight,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
