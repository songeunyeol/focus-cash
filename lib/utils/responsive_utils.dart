import 'package:flutter/material.dart';

/// 화면 너비 600 이상을 태블릿(iPad)으로 간주
extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
  bool get isTablet => screenWidth >= 600;
  bool get isLandscape =>
      MediaQuery.of(this).orientation == Orientation.landscape;

  /// 태블릿일 때 콘텐츠 최대 너비 (가운데 정렬용)
  double get contentMaxWidth => isTablet ? 680.0 : double.infinity;

  /// 화면 너비에 비례한 패딩
  EdgeInsets get responsivePadding =>
      EdgeInsets.symmetric(horizontal: isTablet ? 32.0 : 20.0, vertical: 20.0);
}
