import 'package:flutter/material.dart';

import '../design/ds.dart';

/// 구 디자인 API 파사드.
///
/// 디자인 시스템은 `lib/design/` 으로 옮겨갔다. 이 파일은 기존 호출부(약 658곳)가
/// 수정 없이 새 토큰을 받도록 이름만 유지하는 얇은 층이며, 화면 이행이 끝나면
/// 통째로 삭제한다.
///
/// 새 코드는 `import '../design/ds.dart';` 후 `context.ds`, `DsSurface`, `DsType` 를 쓸 것.
class AppColors {
  const AppColors(this.isDark);

  final bool isDark;

  DsColors get _c => isDark ? DsColors.dark : DsColors.light;

  Color get bg => _c.bg;
  Color get surface => _c.surface;

  /// 구 `card` 는 `surface` 로 통합됐다.
  Color get card => _c.surface;
  Color get elevated => _c.surfaceRaised;
  Color get overlay => _c.surfaceOverlay;

  Color get borderSubtle => _c.borderSubtle;
  Color get borderMid => _c.borderDefault;

  Color get textPrimary => _c.textPrimary;
  Color get textSecondary => _c.textSecondary;
  Color get textMuted => _c.textTertiary;

  /// 상점 전용 배경은 폐지했다. 화면마다 배경이 다를 이유가 없다.
  Color get storeBg => _c.bg;
  Color get storeCard => _c.surface;
}

/// 구 정적 토큰 파사드.
///
/// 주의: 이 값들은 `BuildContext` 가 없어 테마 분기가 불가능하다. 다크 기준 고정값이다.
/// 라이트 테마를 제대로 살리려면 화면 이행 과정에서 이 정적 접근자 호출을 모두
/// `context.ds` 로 옮겨야 한다.
class AppTheme {
  AppTheme._();

  // ── 배경 계층 ──────────────────────────────────────
  static const Color backgroundColor = Color(0xFF07080A);
  static const Color surfaceColor = Color(0xFF101113);
  static const Color cardColor = Color(0xFF101113);
  static const Color elevatedColor = Color(0xFF17191C);
  static const Color overlayColor = Color(0xFF1E2125);

  // ── 테두리 ─────────────────────────────────────────
  static const Color borderSubtle = Color(0x0FFFFFFF);
  static const Color borderMid = Color(0x1AFFFFFF);

  // ── 브랜드 ─────────────────────────────────────────
  // 인디고 + 시안 조합은 제거됐다. 단일 웜 액센트로 통일.
  static const Color primaryColor = Color(0xFFFF7A2F);
  static const Color secondaryColor = Color(0xFFFFA155);

  /// 크레딧 골드도 액센트로 흡수됐다.
  static const Color accentGold = Color(0xFFFF7A2F);
  static const Color creditGold = Color(0xFFFF7A2F);

  // ── 상태 ───────────────────────────────────────────
  static const Color accentGreen = Color(0xFF5FC992);
  static const Color accentRed = Color(0xFFFF6B6B);

  // ── 텍스트 ─────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF4F5F6);
  static const Color textSecondary = Color(0xFFA8ADB4);
  static const Color textMuted = Color(0xFF6E747C);

  // ── 희귀도 ─────────────────────────────────────────
  // 등급이 오를수록 무채색에서 웜 액센트로 옮겨간다. 형태 차별화는 RarityRing 이 맡는다.
  static const Color rarityCommon = Color(0xFF6E747C);
  static const Color rarityRare = Color(0xFFF4F5F6);
  static const Color rarityEpic = Color(0xFFC25A18);
  static const Color rarityLegendary = Color(0xFFFF7A2F);
  static const Color rarityLimited = Color(0xFFFFA155);

  // ── 랭킹 ───────────────────────────────────────────
  static const Color rankGold = Color(0xFFFF7A2F);
  static const Color rankSilver = Color(0xFFF4F5F6);
  static const Color rankBronze = Color(0xFFA8ADB4);

  // ── 그라디언트 ─────────────────────────────────────
  /// 같은 색 2스톱이다. 호출부 28곳을 건드리지 않고 그라디언트를 없애기 위한 장치.
  /// ShaderMask 를 쓰던 자리는 화면 이행 시 통째로 걷어낸다.
  static const LinearGradient primaryGradient = LinearGradient(
    colors: <Color>[Color(0xFFFF7A2F), Color(0xFFFF7A2F)],
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: <Color>[Color(0xFFFF7A2F), Color(0xFFFF7A2F)],
  );

  // ── 버튼 데코 ──────────────────────────────────────
  /// 구 glowButton 의 인디고 glow(alpha 0.4, blur 20)는 제거했다.
  /// 단색 액센트 + 각진 radius 만 남긴다.
  static BoxDecoration get glowButton => const BoxDecoration(
        color: Color(0xFFFF7A2F),
        borderRadius: R.rSm,
      );

  // ── 접근자 ─────────────────────────────────────────
  static AppColors of(BuildContext context) =>
      AppColors(Theme.of(context).brightness == Brightness.dark);

  static ThemeData get lightTheme => DsTheme.light();
  static ThemeData get darkTheme => DsTheme.dark();
}
