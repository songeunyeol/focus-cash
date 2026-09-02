import 'package:flutter/material.dart';

/// Focus Cash 색 토큰.
///
/// 원칙 세 가지:
///  1. 유채색 액센트는 flame 계열 하나뿐이다. 인디고·바이올렛·시안은 쓰지 않는다.
///  2. 다크에서는 그림자가 보이지 않으므로 표면 명도와 헤어라인으로 깊이를 만든다.
///     라이트에서는 반대로 실제 그림자를 쓴다. ([useElevationShadow])
///  3. 순백은 다크 본문 색으로 쓰지 않는다. 눈부심 때문에 F4F5F6 을 쓴다.
@immutable
class DsColors extends ThemeExtension<DsColors> {
  const DsColors({
    required this.voidBlack,
    required this.bg,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceOverlay,
    required this.borderSubtle,
    required this.borderDefault,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.textDim,
    required this.flameDim,
    required this.flame,
    required this.flameBright,
    required this.flameTint,
    required this.accentText,
    required this.onAccent,
    required this.success,
    required this.danger,
    required this.info,
    required this.insetHighlight,
    required this.useElevationShadow,
    required this.shadowE1,
    required this.shadowE2,
    required this.shadowE3,
  });

  // ── 배경·표면 ───────────────────────────────────────
  /// 몰입 모드 전용. AMOLED 픽셀을 실제로 소등시키기 위한 순수 검정.
  final Color voidBlack;
  final Color bg;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceOverlay;

  // ── 테두리 ─────────────────────────────────────────
  final Color borderSubtle;
  final Color borderDefault;
  final Color borderStrong;

  // ── 텍스트 ─────────────────────────────────────────
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textDisabled;

  /// 몰입 모드 저휘도 전용
  final Color textDim;

  // ── 단일 액센트 (불꽃) ──────────────────────────────
  final Color flameDim;
  final Color flame;
  final Color flameBright;
  final Color flameTint;

  /// 액센트를 텍스트로 쓸 때의 색.
  /// flame 은 라이트 배경에서 대비가 3.4:1 에 그쳐 본문에 쓸 수 없으므로
  /// 라이트에서는 flameDim(약 4.8:1)으로 승격한다.
  final Color accentText;

  /// flame 면 위에 올리는 전경색
  final Color onAccent;

  // ── 의미 색 ────────────────────────────────────────
  final Color success;
  final Color danger;
  final Color info;

  // ── 깊이 ───────────────────────────────────────────
  /// e2 표면 상단 1px 하이라이트. 다크에서 물리적 질감을 만든다.
  final Color insetHighlight;

  /// true 면 그림자로, false 면 표면 명도로 깊이를 표현한다.
  final bool useElevationShadow;
  final List<BoxShadow> shadowE1;
  final List<BoxShadow> shadowE2;
  final List<BoxShadow> shadowE3;

  static const DsColors dark = DsColors(
    voidBlack: Color(0xFF000000),
    bg: Color(0xFF07080A),
    surface: Color(0xFF101113),
    surfaceRaised: Color(0xFF17191C),
    surfaceOverlay: Color(0xFF1E2125),
    borderSubtle: Color(0x0FFFFFFF), // white 6%
    borderDefault: Color(0x1AFFFFFF), // white 10%
    borderStrong: Color(0x29FFFFFF), // white 16%
    textPrimary: Color(0xFFF4F5F6),
    textSecondary: Color(0xFFA8ADB4),
    textTertiary: Color(0xFF6E747C),
    textDisabled: Color(0xFF454A51),
    textDim: Color(0xFF3A3D42),
    flameDim: Color(0xFFC25A18),
    flame: Color(0xFFFF7A2F),
    flameBright: Color(0xFFFFA155),
    flameTint: Color(0x24FF7A2F), // flame 14%
    accentText: Color(0xFFFF7A2F),
    onAccent: Color(0xFF07080A),
    success: Color(0xFF5FC992),
    danger: Color(0xFFFF6B6B),
    info: Color(0xFF55B3FF),
    insetHighlight: Color(0x0DFFFFFF), // white 5%
    useElevationShadow: false,
    shadowE1: <BoxShadow>[],
    shadowE2: <BoxShadow>[],
    shadowE3: <BoxShadow>[
      BoxShadow(color: Color(0x80000000), blurRadius: 24, offset: Offset(0, 8)),
    ],
  );

  /// 라이트는 다크의 반전이 아니라 별도 팔레트다.
  /// 푸른빛을 쓰지 않고 따뜻한 뉴트럴(페이퍼) 계열로 간다 — 웜 액센트와 같은 온도.
  static const DsColors light = DsColors(
    voidBlack: Color(0xFF000000),
    bg: Color(0xFFFAF9F7),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceOverlay: Color(0xFFF2F0ED),
    borderSubtle: Color(0x141C1917), // ink 8%
    borderDefault: Color(0x1F1C1917), // ink 12%
    borderStrong: Color(0x2E1C1917), // ink 18%
    textPrimary: Color(0xFF1C1917),
    textSecondary: Color(0xFF57534E),
    textTertiary: Color(0xFF8A827C),
    textDisabled: Color(0xFFC4BEB8),
    textDim: Color(0xFFC4BEB8),
    flameDim: Color(0xFFC25A18),
    flame: Color(0xFFFF7A2F),
    flameBright: Color(0xFFFFA155),
    flameTint: Color(0x1FFF7A2F), // flame 12%
    accentText: Color(0xFFC25A18),
    onAccent: Color(0xFFFFFFFF),
    success: Color(0xFF1F9D63),
    danger: Color(0xFFD64545),
    info: Color(0xFF2A7FD4),
    insetHighlight: Color(0x00FFFFFF),
    useElevationShadow: true,
    shadowE1: <BoxShadow>[
      BoxShadow(color: Color(0x0A1C1917), blurRadius: 2, offset: Offset(0, 1)),
    ],
    shadowE2: <BoxShadow>[
      BoxShadow(color: Color(0x0F1C1917), blurRadius: 8, offset: Offset(0, 2)),
    ],
    shadowE3: <BoxShadow>[
      BoxShadow(color: Color(0x1F1C1917), blurRadius: 24, offset: Offset(0, 8)),
    ],
  );

  @override
  DsColors copyWith({
    Color? voidBlack,
    Color? bg,
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceOverlay,
    Color? borderSubtle,
    Color? borderDefault,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textDisabled,
    Color? textDim,
    Color? flameDim,
    Color? flame,
    Color? flameBright,
    Color? flameTint,
    Color? accentText,
    Color? onAccent,
    Color? success,
    Color? danger,
    Color? info,
    Color? insetHighlight,
    bool? useElevationShadow,
    List<BoxShadow>? shadowE1,
    List<BoxShadow>? shadowE2,
    List<BoxShadow>? shadowE3,
  }) {
    return DsColors(
      voidBlack: voidBlack ?? this.voidBlack,
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceOverlay: surfaceOverlay ?? this.surfaceOverlay,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderDefault: borderDefault ?? this.borderDefault,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textDisabled: textDisabled ?? this.textDisabled,
      textDim: textDim ?? this.textDim,
      flameDim: flameDim ?? this.flameDim,
      flame: flame ?? this.flame,
      flameBright: flameBright ?? this.flameBright,
      flameTint: flameTint ?? this.flameTint,
      accentText: accentText ?? this.accentText,
      onAccent: onAccent ?? this.onAccent,
      success: success ?? this.success,
      danger: danger ?? this.danger,
      info: info ?? this.info,
      insetHighlight: insetHighlight ?? this.insetHighlight,
      useElevationShadow: useElevationShadow ?? this.useElevationShadow,
      shadowE1: shadowE1 ?? this.shadowE1,
      shadowE2: shadowE2 ?? this.shadowE2,
      shadowE3: shadowE3 ?? this.shadowE3,
    );
  }

  @override
  DsColors lerp(ThemeExtension<DsColors>? other, double t) {
    if (other is! DsColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    List<BoxShadow> s(List<BoxShadow> a, List<BoxShadow> b) =>
        BoxShadow.lerpList(a, b, t) ?? b;

    return DsColors(
      voidBlack: c(voidBlack, other.voidBlack),
      bg: c(bg, other.bg),
      surface: c(surface, other.surface),
      surfaceRaised: c(surfaceRaised, other.surfaceRaised),
      surfaceOverlay: c(surfaceOverlay, other.surfaceOverlay),
      borderSubtle: c(borderSubtle, other.borderSubtle),
      borderDefault: c(borderDefault, other.borderDefault),
      borderStrong: c(borderStrong, other.borderStrong),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textTertiary: c(textTertiary, other.textTertiary),
      textDisabled: c(textDisabled, other.textDisabled),
      textDim: c(textDim, other.textDim),
      flameDim: c(flameDim, other.flameDim),
      flame: c(flame, other.flame),
      flameBright: c(flameBright, other.flameBright),
      flameTint: c(flameTint, other.flameTint),
      accentText: c(accentText, other.accentText),
      onAccent: c(onAccent, other.onAccent),
      success: c(success, other.success),
      danger: c(danger, other.danger),
      info: c(info, other.info),
      insetHighlight: c(insetHighlight, other.insetHighlight),
      useElevationShadow:
          t < 0.5 ? useElevationShadow : other.useElevationShadow,
      shadowE1: s(shadowE1, other.shadowE1),
      shadowE2: s(shadowE2, other.shadowE2),
      shadowE3: s(shadowE3, other.shadowE3),
    );
  }
}
