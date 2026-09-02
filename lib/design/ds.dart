import 'package:flutter/material.dart';

import 'ds_colors.dart';
import 'ds_mode.dart';

export 'ds_colors.dart';
export 'ds_dimens.dart';
export 'ds_mode.dart';
export 'ds_rarity.dart';
export 'ds_surfaces.dart';
export 'ds_theme.dart';
export 'ds_typography.dart';

/// 디자인 시스템 진입점.
///
/// 화면 코드는 `import '../../design/ds.dart';` 한 줄만 쓰고
/// `context.ds.textSecondary`, `context.dsMode` 로 접근한다.
extension DsContext on BuildContext {
  /// 색 토큰. 라이트/다크는 ThemeExtension 이 알아서 분기한다.
  DsColors get ds =>
      Theme.of(this).extension<DsColors>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? DsColors.dark
          : DsColors.light);

  /// 현재 서브트리의 모드 (계기 / 보상 / 몰입)
  DsMode get dsMode => DsModeScope.of(this);
}
